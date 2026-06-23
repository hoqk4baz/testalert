#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

static NSUUID *hookedIDFV = nil;

static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    return hookedIDFV;
}

__attribute__((constructor))
static void initialize() {
    // Orijinal değeri kaydet
    NSUUID *originalIDFV = [[UIDevice currentDevice] identifierForVendor];
    
    // Yeni random UUID üret
    hookedIDFV = [NSUUID UUID];
    
    // Hook'u uygula
    Method original = class_getInstanceMethod(
        objc_getClass("UIDevice"),
        @selector(identifierForVendor)
    );
    
    if (original) {
        method_setImplementation(original, (IMP)hook_identifierForVendor);
    }
    
    // UI ana thread'de çalışmalı
    dispatch_async(dispatch_get_main_queue(), ^{
        // Uygulama window'u hazır olana kadar bekle
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), 
                       dispatch_get_main_queue(), ^{
            
            UIWindow *window = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    window = windowScene.windows.firstObject;
                    break;
                }
            }
            
            if (!window) return;
            
            NSString *message = [NSString stringWithFormat:
                @"Önceki IDFV:\n%@\n\nYeni IDFV:\n%@",
                [originalIDFV UUIDString],
                [hookedIDFV UUIDString]
            ];
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"✅ IDFV Değiştirildi"
                message:message
                preferredStyle:UIAlertControllerStyleAlert
            ];
            
            UIAlertAction *ok = [UIAlertAction
                actionWithTitle:@"Tamam"
                style:UIAlertActionStyleDefault
                handler:nil
            ];
            
            [alert addAction:ok];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}
