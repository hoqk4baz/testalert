#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSUUID *fakeIDFV = nil;
static NSString *fakeRawValue = nil;

// IDFV hook
static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    return fakeIDFV;
}

// SecItemCopyMatching hook - okuma
typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef, CFTypeRef *);
static SecItemCopyMatching_t orig_CopyMatching = NULL;

// SecItemAdd hook - ilk yazma
typedef OSStatus (*SecItemAdd_t)(CFDictionaryRef, CFTypeRef *);
static SecItemAdd_t orig_Add = NULL;

// SecItemUpdate hook - güncelleme
typedef OSStatus (*SecItemUpdate_t)(CFDictionaryRef, CFDictionaryRef);
static SecItemUpdate_t orig_Update = NULL;

static NSData *fakeData() {
    return [fakeRawValue dataUsingEncoding:NSUTF8StringEncoding];
}

static void replaceDictResult(CFTypeRef *result) {
    if (!result || !*result) return;
    
    if (CFGetTypeID(*result) == CFDictionaryGetTypeID()) {
        NSDictionary *item = (__bridge NSDictionary *)*result;
        if (item[(__bridge id)kSecValueData]) {
            NSMutableDictionary *m = [item mutableCopy];
            m[(__bridge id)kSecValueData] = fakeData();
            CFTypeRef n = (__bridge_retained CFTypeRef)m;
            CFRelease(*result);
            *result = n;
        }
    } else if (CFGetTypeID(*result) == CFArrayGetTypeID()) {
        NSArray *items = (__bridge NSArray *)*result;
        NSMutableArray *m = [NSMutableArray arrayWithCapacity:items.count];
        for (NSDictionary *item in items) {
            if ([item isKindOfClass:[NSDictionary class]] && item[(__bridge id)kSecValueData]) {
                NSMutableDictionary *mi = [item mutableCopy];
                mi[(__bridge id)kSecValueData] = fakeData();
                [m addObject:mi];
            } else {
                [m addObject:item];
            }
        }
        CFTypeRef n = (__bridge_retained CFTypeRef)m;
        CFRelease(*result);
        *result = n;
    }
}

static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_CopyMatching(query, result);
    if (status == errSecSuccess) replaceDictResult(result);
    return status;
}

static OSStatus hook_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    // Yazılan değeri fake ile değiştir
    NSMutableDictionary *m = [(__bridge NSDictionary *)attributes mutableCopy];
    if (m[(__bridge id)kSecValueData]) {
        m[(__bridge id)kSecValueData] = fakeData();
    }
    return orig_Add((__bridge CFDictionaryRef)m, result);
}

static OSStatus hook_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    NSMutableDictionary *m = [(__bridge NSDictionary *)attributesToUpdate mutableCopy];
    if (m[(__bridge id)kSecValueData]) {
        m[(__bridge id)kSecValueData] = fakeData();
    }
    return orig_Update(query, (__bridge CFDictionaryRef)m);
}

@interface DeviceSpoofer : NSObject
@end

@implementation DeviceSpoofer

+ (void)load {
    fakeIDFV = [NSUUID UUID];
    fakeRawValue = [fakeIDFV UUIDString];
    
    NSLog(@"[Spoofer] Fake ID: %@", fakeRawValue);
    
    // IDFV hook
    Method m = class_getInstanceMethod(objc_getClass("UIDevice"), @selector(identifierForVendor));
    if (m) method_setImplementation(m, (IMP)hook_identifierForVendor);
    
    // Keychain hook - okuma + yazma
    rebind_symbols((struct rebinding[3]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void **)&orig_CopyMatching},
        {"SecItemAdd",          hook_SecItemAdd,          (void **)&orig_Add},
        {"SecItemUpdate",       hook_SecItemUpdate,       (void **)&orig_Update},
    }, 3);
    
    // Alert
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
                message:[NSString stringWithFormat:@"Bu oturumun ID'si:\n%@", fakeRawValue]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
