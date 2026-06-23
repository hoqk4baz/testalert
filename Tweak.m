#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *fakeDeviceId = nil;

// 52 char hex mi kontrol et
static BOOL isDeviceId(NSString *value) {
    if (!value || value.length != 52) return NO;
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    return ([value rangeOfCharacterFromSet:nonHex].location == NSNotFound);
}

static NSString *replaceDeviceId(NSString *str) {
    if (!str) return str;
    return [str stringByReplacingOccurrencesOfString:@"[0-9a-fA-F]{52}"
                                          withString:fakeDeviceId
                                             options:NSRegularExpressionSearch
                                               range:NSMakeRange(0, str.length)];
}

// Header hook
static void (*orig_setValue)(id, SEL, NSString*, NSString*) = NULL;
static void hook_setValue(id self, SEL _cmd, NSString *value, NSString *field) {
    @try {
        if (isDeviceId(value)) {
            orig_setValue(self, _cmd, fakeDeviceId, field);
            return;
        }
    } @catch (NSException *e) {}
    orig_setValue(self, _cmd, value, field);
}

// URL hook - query params burada
static void (*orig_setURL)(id, SEL, NSURL*) = NULL;
static void hook_setURL(id self, SEL _cmd, NSURL *url) {
    @try {
        if (url) {
            NSString *urlStr = url.absoluteString;
            NSString *replaced = replaceDeviceId(urlStr);
            if (![replaced isEqualToString:urlStr]) {
                url = [NSURL URLWithString:replaced];
            }
        }
    } @catch (NSException *e) {}
    orig_setURL(self, _cmd, url);
}

// HTTPBody hook - POST body'de gidiyorsa
static void (*orig_setHTTPBody)(id, SEL, NSData*) = NULL;
static void hook_setHTTPBody(id self, SEL _cmd, NSData *body) {
    @try {
        if (body) {
            NSString *bodyStr = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            if (bodyStr) {
                NSString *replaced = replaceDeviceId(bodyStr);
                if (![replaced isEqualToString:bodyStr]) {
                    body = [replaced dataUsingEncoding:NSUTF8StringEncoding];
                }
            }
        }
    } @catch (NSException *e) {}
    orig_setHTTPBody(self, _cmd, body);
}

@interface DeviceSpoofer : NSObject
@end

@implementation DeviceSpoofer

+ (void)load {
    // 52 char random hex üret
    NSMutableString *hex = [NSMutableString stringWithCapacity:52];
    for (int i = 0; i < 52; i++) {
        [hex appendFormat:@"%x", arc4random_uniform(16)];
    }
    fakeDeviceId = [hex copy];
    
    // Header hook
    Method m1 = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setValue:forHTTPHeaderField:)
    );
    if (m1) {
        orig_setValue = (void(*)(id,SEL,NSString*,NSString*))method_getImplementation(m1);
        method_setImplementation(m1, (IMP)hook_setValue);
    }
    
    // URL hook
    Method m2 = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setURL:)
    );
    if (m2) {
        orig_setURL = (void(*)(id,SEL,NSURL*))method_getImplementation(m2);
        method_setImplementation(m2, (IMP)hook_setURL);
    }
    
    // HTTPBody hook
    Method m3 = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setHTTPBody:)
    );
    if (m3) {
        orig_setHTTPBody = (void(*)(id,SEL,NSData*))method_getImplementation(m3);
        method_setImplementation(m3, (IMP)hook_setHTTPBody);
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
                alertControllerWithTitle:@"✅ Device ID Değiştirildi"
                message:[NSString stringWithFormat:@"Fake ID:\n%@", fakeDeviceId]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
