#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>

#pragma mark - =========================
#pragma mark DEVICE IDENTITY ENGINE
#pragma mark =========================

@interface DeviceIdentityManager : NSObject
@property (nonatomic, strong) NSString *fakeIDFV;
@property (nonatomic, strong) NSString *fakeIDFA;
+ (instancetype)shared;
@end

@implementation DeviceIdentityManager

+ (instancetype)shared {
    static DeviceIdentityManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = [DeviceIdentityManager new];
        [m generate];
    });
    return m;
}

- (NSString *)uuid {
    return [[NSUUID UUID] UUIDString];
}

- (void)generate {
    self.fakeIDFV = [self uuid];
    self.fakeIDFA = [self uuid];
}

- (void)reset {
    [self generate];
}

@end

#pragma mark - =========================
#pragma mark REAL DEVICE INFO
#pragma mark =========================

static NSString *realDeviceInfo() {

    UIDevice *d = UIDevice.currentDevice;
    ASIdentifierManager *ad = [ASIdentifierManager sharedManager];

    return [NSString stringWithFormat:
@"📱 REAL DEVICE\n\n"
"Model: %@\n"
"System: %@ %@\n"
"Name: %@\n"
"REAL IDFV: %@\n"
"REAL IDFA: %@",
d.model,
d.systemName,
d.systemVersion,
d.name,
d.identifierForVendor.UUIDString,
ad.advertisingIdentifier.UUIDString];
}

#pragma mark - =========================
#pragma mark FAKE DEVICE INFO
#pragma mark =========================

static NSString *fakeDeviceInfo() {

    DeviceIdentityManager *m = [DeviceIdentityManager shared];
    UIDevice *d = UIDevice.currentDevice;

    return [NSString stringWithFormat:
@"🎭 FAKE DEVICE (DYLIB)\n\n"
"Fake IDFV: %@\n"
"Fake IDFA: %@\n"
"Model: %@",
m.fakeIDFV,
m.fakeIDFA,
d.model];
}

#pragma mark - =========================
#pragma mark HOOKS
#pragma mark =========================

%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:
            [DeviceIdentityManager shared].fakeIDFV];
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:
            [DeviceIdentityManager shared].fakeIDFA];
}

%end

#pragma mark - =========================
#pragma mark RESET APP DATA
#pragma mark =========================

static void fullResetSandbox() {

    NSFileManager *fm = NSFileManager.defaultManager;

    NSString *home = NSHomeDirectory();

    NSArray *paths = @[
        home,
        [home stringByAppendingPathComponent:@"Documents"],
        [home stringByAppendingPathComponent:@"Library"],
        [home stringByAppendingPathComponent:@"Library/Caches"],
        NSTemporaryDirectory()
    ];

    for (NSString *p in paths) {

        NSArray *items = [fm contentsOfDirectoryAtPath:p error:nil];

        for (NSString *i in items) {
            NSString *fp = [p stringByAppendingPathComponent:i];
            [fm removeItemAtPath:fp error:nil];
        }
    }

    [[NSUserDefaults standardUserDefaults]
     removePersistentDomainForName:
     [[NSBundle mainBundle] bundleIdentifier]];
}

#pragma mark - =========================
#pragma mark TOP VC
#pragma mark =========================

static UIViewController *topVC() {

    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w.rootViewController;
    }
    return nil;
}

#pragma mark - =========================
#pragma mark FLOATING UI
#pragma mark =========================

@interface FloatingPanel : NSObject
@property UIWindow *window;
@property UIView *bubble;
@property BOOL dragging;
@end

@implementation FloatingPanel

+ (instancetype)shared {
    static FloatingPanel *p;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        p = [FloatingPanel new];
    });
    return p;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup {

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.hidden = NO;

    self.bubble = [[UIView alloc] initWithFrame:CGRectMake(180, 220, 80, 80)];
    self.bubble.layer.cornerRadius = 40;
    self.bubble.backgroundColor =
    [[UIColor systemBlueColor] colorWithAlphaComponent:0.85];

    self.bubble.layer.shadowColor = UIColor.blackColor.CGColor;
    self.bubble.layer.shadowOpacity = 0.25;
    self.bubble.layer.shadowRadius = 18;
    self.bubble.layer.shadowOffset = CGSizeMake(0, 10);

    UILabel *l = [[UILabel alloc] initWithFrame:self.bubble.bounds];
    l.text = @"ID";
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont boldSystemFontOfSize:22];
    l.textColor = UIColor.whiteColor;

    [self.bubble addSubview:l];

    UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    [self.bubble addGestureRecognizer:pan];

    UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(open)];

    [self.bubble addGestureRecognizer:tap];

    [self.window addSubview:self.bubble];
}

- (void)move:(UIPanGestureRecognizer *)g {

    CGPoint t = [g translationInView:self.window];

    self.window.center = CGPointMake(self.window.center.x + t.x,
                                     self.window.center.y + t.y);

    [g setTranslation:CGPointZero inView:self.window];

    if (g.state == UIGestureRecognizerStateBegan)
        self.dragging = YES;

    if (g.state == UIGestureRecognizerStateEnded)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            self.dragging = NO;
        });
}

- (void)open {

    if (self.dragging) return;

    DeviceIdentityManager *m = [DeviceIdentityManager shared];

    NSString *msg =
    [NSString stringWithFormat:@"%@\n\n%@", realDeviceInfo(), fakeDeviceInfo()];

    UIAlertController *a =
    [UIAlertController alertControllerWithTitle:@"Device Identity Panel"
                                        message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"🔄 Regenerate Identity"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * _Nonnull action) {
        [m reset];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"🧹 Full Reset App Data"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * _Nonnull action) {
        fullResetSandbox();
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Close"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

    [topVC() presentViewController:a animated:YES completion:nil];
}

@end

#pragma mark - =========================
#pragma mark INIT
#pragma mark =========================

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [FloatingPanel shared];
    });
}
