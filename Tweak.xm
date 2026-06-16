#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

#pragma mark - =====================
#pragma mark CORE ENGINE (SAFE)
#pragma mark =====================

@interface DIEngine : NSObject
@property (nonatomic, strong) NSString *deviceID;
+ (instancetype)shared;
@end

@implementation DIEngine

+ (instancetype)shared {
    static DIEngine *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [DIEngine new];
        d.deviceID = [[NSUUID UUID] UUIDString];
    });
    return d;
}

@end

#pragma mark - =====================
#pragma mark SAFE DEVICE HOOKS
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
#pragma mark SAFE NSUUID ONLY STRING LAYER
#pragma mark =====================

%hook NSUUID

- (NSString *)UUIDString {
    return [DIEngine shared].deviceID;
}

%end

#pragma mark - =====================
#pragma mark SAFE USERDEFAULTS FILTER
#pragma mark =====================

%hook NSUserDefaults

- (id)objectForKey:(NSString *)key {

    id original = %orig;

    if (![original isKindOfClass:[NSString class]] &&
        ![original isKindOfClass:[NSDictionary class]] &&
        ![original isKindOfClass:[NSArray class]]) {
        return original;
    }

    NSString *k = key.lowercaseString;

    if ([k containsString:@"device"] ||
        [k containsString:@"uuid"] ||
        [k containsString:@"idfa"] ||
        [k containsString:@"idfv"] ||
        [k containsString:@"fingerprint"]) {

        return [DIEngine shared].deviceID;
    }

    return original;
}

%end

#pragma mark - =====================
#pragma mark INIT (SAFE)
#pragma mark =====================

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [DIEngine shared];
    });
}
