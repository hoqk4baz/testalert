#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSUUID *fakeIDFV = nil;
static NSString *fakeRawValue = nil;
static NSMutableArray *keychainLogs = nil;

typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef, CFTypeRef *);
typedef OSStatus (*SecItemAdd_t)(CFDictionaryRef, CFTypeRef *);
typedef OSStatus (*SecItemUpdate_t)(CFDictionaryRef, CFDictionaryRef);

static SecItemCopyMatching_t orig_CopyMatching = NULL;
static SecItemAdd_t orig_Add = NULL;
static SecItemUpdate_t orig_Update = NULL;

static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    return fakeIDFV;
}

static NSString *describeKeychainItem(NSDictionary *item) {
    NSString *service = item[(__bridge id)kSecAttrService] ?: @"-";
    NSString *account = item[(__bridge id)kSecAttrAccount] ?: @"-";
    NSData *valueData = item[(__bridge id)kSecValueData];
    NSString *value = @"-";
    if (valueData) {
        value = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
        if (!value) value = [valueData base64EncodedStringWithOptions:0];
    }
    return [NSString stringWithFormat:@"service=%@ account=%@ value=%@", service, account, value];
}

static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_CopyMatching(query, result);
    
    if (status == errSecSuccess && result && *result) {
        if (CFGetTypeID(*result) == CFDictionaryGetTypeID()) {
            NSString *log = [NSString stringWithFormat:@"[READ] %@",
                describeKeychainItem((__bridge NSDictionary *)*result)];
            [keychainLogs addObject:log];
        } else if (CFGetTypeID(*result) == CFArrayGetTypeID()) {
            for (NSDictionary *item in (__bridge NSArray *)*result) {
                NSString *log = [NSString stringWithFormat:@"[READ] %@",
                    describeKeychainItem(item)];
                [keychainLogs addObject:log];
            }
        }
    }
    
    return status;
}

static OSStatus hook_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    NSDictionary *a = (__bridge NSDictionary *)attributes;
    NSString *log = [NSString stringWithFormat:@"[ADD] %@", describeKeychainItem(a)];
    [keychainLogs addObject:log];
    return orig_Add(attributes, result);
}

static OSStatus hook_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    NSDictionary *u = (__bridge NSDictionary *)attributesToUpdate;
    NSString *log = [NSString stringWithFormat:@"[UPDATE] %@", describeKeychainItem(u)];
    [keychainLogs addObject:log];
    return orig_Update(query, attributesToUpdate);
}

@interface DeviceSpoofer : NSObject
@end

@implementation DeviceSpoofer

+ (void)load {
    keychainLogs = [NSMutableArray array];
    fakeIDFV = [NSUUID UUID];
    fakeRawValue = [fakeIDFV UUIDString];
    
    Method m = class_getInstanceMethod(objc_getClass("UIDevice"), @selector(identifierForVendor));
    if (m) method_setImplementation(m, (IMP)hook_identifierForVendor);
    
    rebind_symbols((struct rebinding[3]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void **)&orig_CopyMatching},
        {"SecItemAdd",          hook_SecItemAdd,          (void **)&orig_Add},
        {"SecItemUpdate",       hook_SecItemUpdate,       (void **)&orig_Update},
    }, 3);
    
    // 3 saniye bekle - uygulama Keychain'i okusun
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            
            UIWindow *window = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    window = ((UIWindowScene *)scene).windows.firstObject;
                    break;
                }
            }
            if (!window) return;
            
            NSString *logs = keychainLogs.count > 0
                ? [keychainLogs componentsJoinedByString:@"\n\n"]
                : @"Keychain erişimi tespit edilmedi";
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Keychain Log"
                message:logs
                preferredStyle:UIAlertControllerStyleAlert
            ];
            
            // Kopyala butonu
            [alert addAction:[UIAlertAction
                actionWithTitle:@"Kopyala"
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    [UIPasteboard generalPasteboard].string = logs;
                }
            ]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
