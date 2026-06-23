#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *fakeDeviceId = nil;
static void (*orig_setValue)(id, SEL, NSString*, NSString*) = NULL;

static void hook_setValue(id self, SEL _cmd, NSString *value, NSString *field) {
    @try {
        if (field && [field isEqualToString:@"deviceId"]) {
            // Fake değeri geçir, orijinali geçirme
            orig_setValue(self, _cmd, fakeDeviceId, field);
            return;
        }
    } @catch (NSException *e) {}
    
    orig_setValue(self, _cmd, value, field);
}

@interface DeviceSpoofer : NSObject
@end

@implementation DeviceSpoofer

+ (void)load {
    // Her açılışta yeni random hex üret (52 char - orijinalle aynı format)
    NSMutableString *hex = [NSMutableString stringWithCapacity:52];
    for (int i = 0; i < 52; i++) {
        [hex appendFormat:@"%x", arc4random_uniform(16)];
    }
    fakeDeviceId = [hex copy];
    
    Method m = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setValue:forHTTPHeaderField:)
    );
    
    if (m) {
        orig_setValue = (void(*)(id,SEL,NSString*,NSString*))method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_setValue);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            
            UIWindow *window = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    window = ((UIWindowScene *)scene).windows.firstObject;
                    break;
                }
            }
            if (!window) return;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"✅ deviceId Değiştirildi"
                message:[NSString stringWithFormat:@"Fake deviceId:\n%@", fakeDeviceId]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
