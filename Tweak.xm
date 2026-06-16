#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <dlfcn.h>
#import "fishhook.h"

static NSString *randomUUID(void) {
    return [[NSUUID UUID] UUIDString];
}

// ====================== FLOATING BUBBLE ======================
@interface DeviceSpooferBubble : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *bubbleButton;
@end

@implementation DeviceSpooferBubble

+ (instancetype)shared {
    static DeviceSpooferBubble *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DeviceSpooferBubble alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self createBubble];
    }
    return self;
}

- (void)createBubble {
    // Ekranın sağ üst köşesinde başlasın
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake([[UIScreen mainScreen] bounds].size.width - 80, 80, 60, 60)];
    self.window.windowLevel = UIWindowLevelAlert + 100;   // Daha üstte olsun
    self.window.backgroundColor = [UIColor clearColor];
    self.window.hidden = NO;

    self.bubbleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.bubbleButton.frame = CGRectMake(0, 0, 60, 60);
    self.bubbleButton.backgroundColor = [UIColor systemBlueColor];
    self.bubbleButton.layer.cornerRadius = 30;
    self.bubbleButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.bubbleButton.layer.shadowOffset = CGSizeMake(0, 3);
    self.bubbleButton.layer.shadowOpacity = 0.6;
    
    [self.bubbleButton setTitle:@"🔄" forState:UIControlStateNormal];
    self.bubbleButton.titleLabel.font = [UIFont systemFontOfSize:32];
    
    [self.bubbleButton addTarget:self action:@selector(showPanel) forControlEvents:UIControlEventTouchUpInside];
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    [vc.view addSubview:self.bubbleButton];
    self.window.rootViewController = vc;
    
    // Sürükleme özelliği
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.bubbleButton addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint translation = [g translationInView:self.window];
    CGPoint center = self.bubbleButton.center;
    center.x += translation.x;
    center.y += translation.y;
    self.bubbleButton.center = center;
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
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Değiştir" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self resetAndRestart];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
}

- (void)resetAndRestart {
    NSString *domain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domain];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Başarılı"
                                                                   message:@"Veriler temizlendi.\nUygulama yeniden başlatılıyor..."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }];
}

@end

// ====================== HOOKS ======================

static NSUUID* (*orig_identifierForVendor)(id, SEL);
static NSUUID* spoof_identifierForVendor(id self, SEL _cmd) {
    static NSUUID *fakeID = nil;
    if (!fakeID) fakeID = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return fakeID;
}

static NSUUID* (*orig_advertisingIdentifier)(id, SEL);
static NSUUID* spoof_advertisingIdentifier(id self, SEL _cmd) {
    static NSUUID *fakeID = nil;
    if (!fakeID) fakeID = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return fakeID;
}

%ctor {
    NSLog(@"[DeviceSpoofer] ✅ Yüzen baloncuk aktif - App açılışta görünecek");

    struct rebinding rebindings[] = {
        {"identifierForVendor", (void *)spoof_identifierForVendor, (void **)&orig_identifierForVendor},
        {"advertisingIdentifier", (void *)spoof_advertisingIdentifier, (void **)&orig_advertisingIdentifier},
    };
    rebind_symbols(rebindings, 2);

    // Bubble'ı hemen başlat
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [DeviceSpooferBubble shared];
    });
}
