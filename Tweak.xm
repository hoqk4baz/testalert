#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <Foundation/Foundation.h>

#pragma mark - =====================
#pragma mark CORE ID ENGINE
#pragma mark =====================

@interface DIEngine : NSObject
@property (nonatomic, strong) NSString *deviceID;
+ (instancetype)shared;
- (void)regen;
@end

@implementation DIEngine

+ (instancetype)shared {
    static DIEngine *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [DIEngine new];
        [d regen];
    });
    return d;
}

- (NSString *)uuid {
    return [[NSUUID UUID] UUIDString];
}

- (void)regen {
    self.deviceID = [self uuid];
}

@end

#pragma mark - =====================
#pragma mark UID / IDFA LAYER
#pragma mark =====================

%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:[DIEngine shared].deviceID];
}

%end


%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:[DIEngine shared].deviceID];
}

%end

#pragma mark - =====================
#pragma mark UUID GENERATION LAYER
#pragma mark =====================

%hook NSUUID

+ (instancetype)UUID {
    return [[NSUUID alloc] initWithUUIDString:[DIEngine shared].deviceID];
}

+ (instancetype)UUIDWithUUIDString:(NSString *)UUIDString {
    return [[NSUUID alloc] initWithUUIDString:[DIEngine shared].deviceID];
}

- (NSString *)UUIDString {
    return [DIEngine shared].deviceID;
}

%end

#pragma mark - =====================
#pragma mark STRING UUID HOOK
#pragma mark =====================

%hook NSString

+ (NSString *)stringWithUUID {
    return [DIEngine shared].deviceID;
}

%end

#pragma mark - =====================
#pragma mark USERDEFAULTS FINGERPRINT LAYER
#pragma mark =====================

%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {

    NSString *k = key.lowercaseString;

    if ([k containsString:@"device"] ||
        [k containsString:@"uuid"] ||
        [k containsString:@"idfa"] ||
        [k containsString:@"idfv"] ||
        [k containsString:@"fingerprint"] ||
        [k containsString:@"advertising"] ||
        [k containsString:@"tracking"]) {

        return [DIEngine shared].deviceID;
    }

    return %orig;
}

%end

#pragma mark - =====================
#pragma mark CFUUID (SYSTEM COMPAT)
#pragma mark =====================

CFUUIDRef CFUUIDCreate(CFAllocatorRef allocator) {
    CFUUIDRef ref = CFUUIDCreateFromString(NULL,
        (__bridge CFStringRef)[DIEngine shared].deviceID);
    return ref;
}

#pragma mark - =====================
#pragma mark NETWORK HEADER SPOOF (BASIC)
#pragma mark =====================

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {

    NSString *f = field.lowercaseString;

    if ([f containsString:@"device"] ||
        [f containsString:@"idfa"] ||
        [f containsString:@"idfv"] ||
        [f containsString:@"uuid"]) {

        value = [DIEngine shared].deviceID;
    }

    %orig(field, value);
}

%end

#pragma mark - =====================
#pragma mark OPTIONAL: RANDOM ROTATION
#pragma mark =====================

static void regenIdentity(void) {
    [[DIEngine shared] regen];
}

#pragma mark - =====================
#pragma mark INIT
#pragma mark =====================

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        regenIdentity();
    });
}
