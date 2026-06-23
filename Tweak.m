#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include "fishhook.h"

static NSString *fakeDeviceId = nil;
static NSString *realDeviceId = nil;
static NSMutableArray *logs = nil;

// NSMutableURLRequest hook
static void (*orig_setValue)(id, SEL, NSString*, NSString*) = NULL;
static void hook_setValue(id self, SEL _cmd, NSString *value, NSString *field) {
    @try {
        if (field && [field isEqualToString:@"deviceId"] && value) {
            if (!realDeviceId) realDeviceId = [value copy];
            orig_setValue(self, _cmd, fakeDeviceId, field);
            return;
        }
    } @catch (NSException *e) {}
    orig_setValue(self, _cmd, value, field);
}

// CFHTTPMessageSetHeaderFieldValue hook - low level HTTP
typedef void (*CFHTTPMessageSetHeader_t)(CFHTTPMessageRef, CFStringRef, CFStringRef);
static CFHTTPMessageSetHeader_t orig_CFHTTPSet = NULL;
static void hook_CFHTTPSet(CFHTTPMessageRef msg, CFStringRef field, CFStringRef value) {
    @try {
        NSString *f = (__bridge NSString *)field;
        NSString *v = (__bridge NSString *)value;
        if ([f isEqualToString:@"deviceId"] && v) {
            if (!realDeviceId) realDeviceId = [v copy];
            orig_CFHTTPSet(msg, field, (__bridge CFStringRef)fakeDeviceId);
            return;
        }
    } @catch (NSException *e) {}
    orig_CFHTTPSet(msg, field, value);
}

// NSURLRequest allHTTPHeaderFields hook - header dict olarak set edenler için
static NSDictionary *(*orig_allHeaders)(id, SEL) = NULL;
static NSDictionary *hook_allHeaders(id self, SEL _cmd) {
    NSDictionary *headers = orig_allHeaders(self, _cmd);
    if (headers[@"deviceId"]) {
        NSMutableDictionary *m = [headers mutableCopy];
        if (!realDeviceId) realDeviceId = [headers[@"deviceId"] copy];
        m[@"deviceId"] = fakeDeviceId;
        return [m copy];
    }
    return headers;
}

// setAllHTTPHeaderFields hook
static void (*orig_setAllHeaders)(id, SEL, NSDictionary*) = NULL;
static void hook_setAllHeaders(id self, SEL _cmd, NSDictionary *headers) {
    @try {
        if (headers[@"deviceId"]) {
            NSMutableDictionary *m = [headers mutableCopy];
            if (!realDeviceId) realDeviceId = [headers[@"deviceId"] copy];
            m[@"deviceId"] = fakeDeviceId;
            orig_setAllHeaders(self, _cmd, [m copy]);
            return;
        }
    } @catch (NSException *e) {}
    orig_setAllHeaders(self, _cmd, headers);
}

@interface DeviceSpoofer : NSObject
@end

@implementation DeviceSpoofer

+ (void)load {
    logs = [NSMutableArray array];
    
    // Fake ID - Keychain'den oku, yoksa üret ve kaydet
    NSString *keychainService = @"com.spoofer.deviceid";
    NSDictionary *readQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: keychainService,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)readQuery, &result);
    
    if (status == errSecSuccess && result) {
        NSData *data = (__bridge_transfer NSData *)result;
        fakeDeviceId = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    if (!fakeDeviceId) {
        // Yeni üret - aynı format: 52 char hex
        NSMutableString *hex = [NSMutableString stringWithCapacity:52];
        for (int i = 0; i < 52; i++) {
            [hex appendFormat:@"%x", arc4random_uniform(16)];
        }
        fakeDeviceId = [hex copy];
        
        // Keychain'e kaydet
        NSDictionary *addQuery = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: keychainService,
            (__bridge id)kSecAttrAccount: @"deviceid",
            (__bridge id)kSecValueData: [fakeDeviceId dataUsingEncoding:NSUTF8StringEncoding],
            (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly
        };
        SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    }
    
    // NSMutableURLRequest hook
    Method m1 = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setValue:forHTTPHeaderField:)
    );
    if (m1) {
        orig_setValue = (void(*)(id,SEL,NSString*,NSString*))method_getImplementation(m1);
        method_setImplementation(m1, (IMP)hook_setValue);
    }
    
    // setAllHTTPHeaderFields hook
    Method m2 = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setAllHTTPHeaderFields:)
    );
    if (m2) {
        orig_setAllHeaders = (void(*)(id,SEL,NSDictionary*))method_getImplementation(m2);
        method_setImplementation(m2, (IMP)hook_setAllHeaders);
    }
    
    // allHTTPHeaderFields hook
    Method m3 = class_getInstanceMethod(
        objc_getClass("NSURLRequest"),
        @selector(allHTTPHeaderFields)
    );
    if (m3) {
        orig_allHeaders = (NSDictionary*(*)(id,SEL))method_getImplementation(m3);
        method_setImplementation(m3, (IMP)hook_allHeaders);
    }
    
    // CFHTTPMessageSetHeaderFieldValue hook - fishhook ile
    rebind_symbols((struct rebinding[1]){
        {"CFHTTPMessageSetHeaderFieldValue", hook_CFHTTPSet, (void **)&orig_CFHTTPSet}
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
                alertControllerWithTitle:@"✅ Device ID"
                message:[NSString stringWithFormat:@"Fake:\n%@\n\nGerçek:\n%@",
                    fakeDeviceId,
                    realDeviceId ?: @"henüz tespit edilmedi"
                ]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
