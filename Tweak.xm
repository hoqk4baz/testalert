#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "fishhook.h"

static NSString *randomUUID(void) {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomString(int length) {
    NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [s appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)letters.length)]];
    }
    return s;
}

// ====================== FLOATING BUBBLE ======================
@interface DeviceSpooferBubble : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *bubbleButton;
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
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(20, 100, 60, 60)];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.hidden = NO;

    self.bubbleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.bubbleButton.frame = CGRectMake(0, 0, 60, 60);
    self.bubbleButton.backgroundColor = [UIColor systemBlueColor];
    self.bubbleButton.layer.cornerRadius = 30;
    [self.bubbleButton setTitle:@"🔄" forState:UIControlStateNormal];
    self.bubbleButton.titleLabel.font = [UIFont systemFontOfSize:28];
    
    [self.bubbleButton addTarget:self action:@selector(showPanel) forControlEvents:UIControlEventTouchUpInside];
    
    UIViewController *vc = [[UIViewController alloc] init];
    [vc.view addSubview:self.bubbleButton];
    self.window.rootViewController = vc;
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.bubbleButton addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint p = [g translationInView:self.window];
    CGPoint c = self.bubbleButton.center;
    c.x += p.x; c.y += p.y;
    self.bubbleButton.center = c;
    [g setTranslation:CGPointZero inView:self.window];
}

- (void)showPanel {
    NSString *info = [NSString stringWithFormat:
        @"IDFV: %@\nIDFA: %@\nModel: %@",
        [[UIDevice currentDevice] identifierForVendor].UUIDString ?: @"-",
        [[ASIdentifierManager sharedManager] advertisingIdentifier].UUIDString ?: @"-",
        [[UIDevice currentDevice] model]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Device Spoofer" 
                                                                   message:info
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Değiştir" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self resetAndRestart];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    
    [[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)resetAndRestart {
    // App verilerini temizle
    NSString *domain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domain];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // Cache temizle
    [[NSFileManager defaultManager] removeItemAtPath:NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject error:nil];
    
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Başarılı" 
                                                              message:@"Veriler temizlendi.\nUygulama yeniden başlatılıyor..." 
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:a animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }];
}
@end

// ====================== HOOK'LAR (fishhook ile) ======================

static NSUUID* (*orig_identifierForVendor)(id self, SEL _cmd);
static NSUUID* spoof_identifierForVendor(id self, SEL _cmd) {
    static NSUUID *fake = nil;
    if (!fake) fake = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return fake;
}

static NSUUID* (*orig_advertisingIdentifier)(id self, SEL _cmd);
static NSUUID* spoof_advertisingIdentifier(id self, SEL _cmd) {
    static NSUUID *fake = nil;
    if (!fake) fake = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return fake;
}

%ctor {
    NSLog(@"[DeviceSpoofer] ✅ Jailbreak'siz mod - Floating Bubble Loaded");

    // fishhook ile hook kur
    struct rebinding rebindings[] = {
        {"identifierForVendor", (void *)spoof_identifierForVendor, (void **)&orig_identifierForVendor},
        {"advertisingIdentifier", (void *)spoof_advertisingIdentifier, (void **)&orig_advertisingIdentifier},
    };
    rebind_symbols(rebindings, sizeof(rebindings)/sizeof(rebindings[0]));

    // MobileGestalt için basit hook (daha ileri seviye istersen söyle)
    [DeviceSpooferBubble shared];
}
