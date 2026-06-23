#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#import <dlfcn.h>
#include "fishhook.h"

static NSUUID *fakeIDFV = nil;
static NSString *fakeRawValue = nil;

// IDFV hook
static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    return fakeIDFV;
}

// SecItemCopyMatching hook
typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef query, CFTypeRef *result);
static SecItemCopyMatching_t original_SecItemCopyMatching = NULL;

static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = original_SecItemCopyMatching(query, result);
    
    if (status != errSecSuccess || !result || !*result) return status;
    
    NSData *fakeData = [fakeRawValue dataUsingEncoding:NSUTF8StringEncoding];
    
    // Tek item - NSDictionary
    if (CFGetTypeID(*result) == CFDictionaryGetTypeID()) {
        NSDictionary *item = (__bridge NSDictionary *)*result;
        NSData *valueData = item[(__bridge id)kSecValueData];
        if (valueData) {
            NSString *original = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
            NSLog(@"[Spoofer] Keychain orijinal: %@", original);
            
            NSMutableDictionary *mutable = [item mutableCopy];
            mutable[(__bridge id)kSecValueData] = fakeData;
            CFTypeRef new = (__bridge_retained CFTypeRef)mutable;
            CFRelease(*result);
            *result = new;
        }
        return status;
    }
    
    // Çoklu item - NSArray
    if (CFGetTypeID(*result) == CFArrayGetTypeID()) {
        NSArray *items = (__bridge NSArray *)*result;
        NSMutableArray *mutable = [NSMutableArray arrayWithCapacity:items.count];
        
        for (id item in items) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                NSData *valueData = item[(__bridge id)kSecValueData];
                if (valueData) {
                    NSString *original = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
                    NSLog(@"[Spoofer] Keychain orijinal: %@", original);
                    
                    NSMutableDictionary *mutableItem = [item mutableCopy];
                    mutableItem[(__bridge id)kSecValueData] = fakeData;
                    [mutable addObject:mutableItem];
                    continue;
                }
            }
            [mutable addObject:item];
        }
        
        CFTypeRef new = (__bridge_retained CFTypeRef)mutable;
        CFRelease(*result);
        *result = new;
    }
    
    return status;
}

@interface DeviceSpoofer : NSObject
@end

@implementation DeviceSpoofer

+ (void)load {
    // Her açılışta yeni random değer üret
    fakeIDFV = [NSUUID UUID];
    fakeRawValue = [fakeIDFV UUIDString];
    
    // IDFV hook
    Method m = class_getInstanceMethod(
        objc_getClass("UIDevice"),
        @selector(identifierForVendor)
    );
    if (m) method_setImplementation(m, (IMP)hook_identifierForVendor);
    
    // SecItemCopyMatching hook - fishhook ile
    rebind_symbols((struct rebinding[1]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void **)&original_SecItemCopyMatching}
    }, 1);
    
    NSLog(@"[Spoofer] Yüklendi. Fake IDFV: %@", fakeRawValue);
    
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
                message:[NSString stringWithFormat:@"Fake IDFV:\n%@", fakeRawValue]
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
