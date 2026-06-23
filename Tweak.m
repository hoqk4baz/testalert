#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSUUID *fakeIDFV = nil;
static NSString *fakeRawValue = nil;

typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef, CFTypeRef *);
static SecItemCopyMatching_t orig_CopyMatching = NULL;

static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    return fakeIDFV;
}

static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_CopyMatching(query, result);
    return status;
}

static void writeDeviceIdToKeychain(NSString *value) {
    NSArray *services = @[@"deviceUUID3", @"deviceiOSUUEx3"];
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    for (NSString *service in services) {
        NSDictionary *deleteQuery = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: service
        };
        SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        
        NSDictionary *addQuery = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: service,
            (__bridge id)kSecAttrAccount: @"",
            (__bridge id)kSecValueData: valueData,
            (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly
        };
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
        NSLog(@"[Spoofer] %@ -> status: %d", service, (int)status);
    }
}

@interface DeviceSpoofer : NSObject
@end

@implementation DeviceSpoofer

+ (void)load {
    fakeIDFV = [NSUUID UUID];
    fakeRawValue = [fakeIDFV UUIDString];
    
    // 1. Keychain'e fake değeri yaz
    writeDeviceIdToKeychain(fakeRawValue);
    
    // 2. IDFV hook
    Method m = class_getInstanceMethod(objc_getClass("UIDevice"), @selector(identifierForVendor));
    if (m) method_setImplementation(m, (IMP)hook_identifierForVendor);
    
    // 3. fishhook
    rebind_symbols((struct rebinding[1]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void **)&orig_CopyMatching},
    }, 1);
    
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
                alertControllerWithTitle:@"✅ Device ID Değiştirildi"
                message:[NSString stringWithFormat:@"Fake ID:\n%@", fakeRawValue]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
