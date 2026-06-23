#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

static NSUUID *hookedIDFV = nil;
static NSUUID *originalIDFV = nil;

static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    return hookedIDFV;
}

@interface IDFVSpoofer : NSObject
@end

@implementation IDFVSpoofer

+ (void)load {
    Method original = class_getInstanceMethod(
        objc_getClass("UIDevice"),
        @selector(identifierForVendor)
    );
    
    if (!original) return;
    
    // Önce orijinal değeri oku
    originalIDFV = [[UIDevice currentDevice] identifierForVendor];
    
    // Sonra hook'u uygula
    hookedIDFV = [NSUUID UUID];
    method_setImplementation(original, (IMP)hook_identifierForVendor);
    
    // Alert — window hazır olmadığı için bekle
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            
            UIWindow *window = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    window = ((UIWindowScene *)scene).windows.firstObject;
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
            
            [alert addAction:[UIAlertAction
                actionWithTitle:@"Tamam"
                style:UIAlertActionStyleDefault
                handler:nil
            ]];
            
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
