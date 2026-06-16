#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <dlfcn.h>
#import "fishhook.h"

static NSString *randomUUID(void) {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomString(int len) {
    NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < len; i++) {
        [s appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)letters.length)]];
    }
    return s;
}

// ====================== GÜZEL FLOATING BUBBLE ======================
@interface DeviceSpooferBubble : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *bubble;
@end

@implementation DeviceSpooferBubble

+ (instancetype)shared {
    static DeviceSpooferBubble *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) [self createBubble];
    return self;
}

- (void)createBubble {
    CGRect screen = [[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(screen.size.width - 75, 120, 65, 65)];
    self.window.windowLevel = UIWindowLevelAlert + 200;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.hidden = NO;

    self.bubble = [UIButton buttonWithType:UIButtonTypeSystem];
    self.bubble.frame = CGRectMake(0, 0, 65, 65);
    self.bubble.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.95];
    self.bubble.layer.cornerRadius = 32.5;
    self.bubble.layer.shadowColor = [UIColor blackColor].CGColor;
    self.bubble.layer.shadowOffset = CGSizeMake(0, 4);
    self.bubble.layer.shadowRadius = 8;
    self.bubble.layer.shadowOpacity = 0.6;
    
    [self.bubble setTitle:@"🔄" forState:UIControlStateNormal];
    self.bubble.titleLabel.font = [UIFont systemFontOfSize:35 weight:UIFontWeightBold];
    
    [self.bubble addTarget:self action:@selector(showPanel) forControlEvents:UIControlEventTouchUpInside];
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    [vc.view addSubview:self.bubble];
    self.window.rootViewController = vc;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.bubble addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.window];
    CGPoint center = self.bubble.center;
    center.x += translation.x;
    center.y += translation.y;
    self.bubble.center = center;
    [pan setTranslation:CGPointZero inView:self.window];
}

- (void)showPanel {
    NSMutableString *info = [NSMutableString string];
    UIDevice *dev = [UIDevice currentDevice];
    ASIdentifierManager *idm = [ASIdentifierManager sharedManager];
    
    [info appendFormat:@"IDFV: %@\n", dev.identifierForVendor.UUIDString ?: @"-"];
    [info appendFormat:@"IDFA: %@\n", idm.advertisingIdentifier.UUIDString ?: @"-"];
    [info appendFormat:@"Model: %@\n", dev.model];
    [info appendFormat:@"System: %@ %@\n", dev.systemName, dev.systemVersion];
    [info appendFormat:@"Name: %@\n", dev.name];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Device Spoofer"
                                                                   message:info
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"🔄 Değiştir & Yeniden Başlat" 
                                              style:UIAlertActionStyleDestructive 
                                            handler:^(UIAlertAction *action) {
        [self resetAndRestart];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)resetAndRestart {
    // Tüm uygulama verilerini temizle
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // Cache temizliği
    [[NSFileManager defaultManager] removeItemAtPath:NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject error:nil];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Başarılı" 
                                                                   message:@"Tüm cihaz bilgileri değiştirildi.\nUygulama yeniden başlatılıyor..." 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }];
}

@end

// ====================== DERİN SPOOF ======================

static NSUUID* (*orig_idfv)(id, SEL);
static NSUUID* spoof_idfv(id self, SEL _cmd) {
    static NSUUID *fake = nil;
    if (!fake) fake = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return fake;
}

static NSUUID* (*orig_idfa)(id, SEL);
static NSUUID* spoof_idfa(id self, SEL _cmd) {
    static NSUUID *fake = nil;
    if (!fake) fake = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return fake;
}

// MobileGestalt Hook (daha derin)
%hookf(CFStringRef, MGCopyAnswer, CFStringRef key) {
    NSString *k = (__bridge NSString *)key;
    
    if ([k containsString:@"UniqueDeviceID"] || [k containsString:@"UDID"]) {
        return (__bridge CFStringRef)randomUUID();
    }
    if ([k containsString:@"SerialNumber"]) {
        return (__bridge CFStringRef)randomString(12);
    }
    if ([k isEqualToString:@"ProductType"]) {
        return CFSTR("iPhone14,5"); // iPhone 13 gibi
    }
    return %orig;
}

%ctor {
    NSLog(@"[DeviceSpoofer] ✅ Güzel UI + Derin Spoof Aktif");

    struct rebinding rebs[] = {
        {"identifierForVendor", (void*)spoof_idfv, (void**)&orig_idfv},
        {"advertisingIdentifier", (void*)spoof_idfa, (void**)&orig_idfa},
    };
    rebind_symbols(rebs, 2);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [DeviceSpooferBubble shared];
    });
}
