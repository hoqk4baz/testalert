#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

#pragma mark - FAKE STORAGE

static NSString *fakeIDFV;
static NSString *fakeIDFA;

static NSString *UUIDGen() {
    return [[NSUUID UUID] UUIDString];
}

static void ensureFake() {
    if (!fakeIDFV) fakeIDFV = UUIDGen();
    if (!fakeIDFA) fakeIDFA = UUIDGen();
}

static void regenerateIDs() {
    fakeIDFV = UUIDGen();
    fakeIDFA = UUIDGen();
}

#pragma mark - REAL DEVICE INFO

static NSString *realDeviceInfo() {
    UIDevice *d = UIDevice.currentDevice;
    ASIdentifierManager *ad = [ASIdentifierManager sharedManager];

    return [NSString stringWithFormat:
            @"📱 REAL DEVICE INFO\n\n"
            @"Model: %@\n"
            @"System: %@ %@\n"
            @"Name: %@\n"
            @"REAL IDFV: %@\n"
            @"REAL IDFA: %@",
            d.model,
            d.systemName,
            d.systemVersion,
            d.name,
            d.identifierForVendor.UUIDString,
            ad.advertisingIdentifier.UUIDString];
}

static NSString *fakeDeviceInfo() {
    ensureFake();

    UIDevice *d = UIDevice.currentDevice;

    return [NSString stringWithFormat:
            @"🎭 SPOOFED INFO\n\n"
            @"Fake IDFV: %@\n"
            @"Fake IDFA: %@\n"
            @"Model: %@",
            fakeIDFV,
            fakeIDFA,
            d.model];
}

#pragma mark - RESET APP DATA

static void fullResetAppData() {

    NSFileManager *fm = NSFileManager.defaultManager;

    NSArray *paths = @[
        NSHomeDirectory(),
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library"],
        [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"],
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"],
        NSTemporaryDirectory()
    ];

    for (NSString *path in paths) {
        NSError *err = nil;
        NSArray *items = [fm contentsOfDirectoryAtPath:path error:&err];
        for (NSString *item in items) {
            NSString *full = [path stringByAppendingPathComponent:item];
            [fm removeItemAtPath:full error:nil];
        }
    }

    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:
     [[NSBundle mainBundle] bundleIdentifier]];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - HOOKS (SPOOF)

%hook UIDevice

- (NSUUID *)identifierForVendor {
    ensureFake();
    return [[NSUUID alloc] initWithUUIDString:fakeIDFV];
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    ensureFake();
    return [[NSUUID alloc] initWithUUIDString:fakeIDFA];
}

%end

#pragma mark - TOP VC

static UIViewController *topVC() {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w.rootViewController;
    }
    return nil;
}

#pragma mark - UI BUBBLE

@interface Bubble : NSObject
@property UIWindow *window;
@property UIButton *btn;
@property BOOL dragging;
@end

@implementation Bubble

+ (instancetype)shared {
    static Bubble *b;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        b = [Bubble new];
    });
    return b;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup {

    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(200, 120, 72, 72)];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = UIColor.clearColor;

    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    UIVisualEffectView *glass =
    [[UIVisualEffectView alloc] initWithEffect:
     [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];

    glass.frame = CGRectMake(0, 0, 72, 72);
    glass.layer.cornerRadius = 36;
    glass.clipsToBounds = YES;

    glass.layer.shadowColor = UIColor.blackColor.CGColor;
    glass.layer.shadowOpacity = 0.25;
    glass.layer.shadowRadius = 15;
    glass.layer.shadowOffset = CGSizeMake(0, 10);

    self.btn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btn.frame = glass.bounds;

    if (@available(iOS 13.0, *)) {
        UIImage *img =
        [UIImage systemImageNamed:@"iphone.circle.fill"];

        self.btn.tintColor = UIColor.systemBlueColor;
        [self.btn setImage:img forState:UIControlStateNormal];
    } else {
        [self.btn setTitle:@"📱" forState:UIControlStateNormal];
        self.btn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    }

    [self.btn addTarget:self action:@selector(openPanel)
        forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    pan.cancelsTouchesInView = NO;

    [self.btn addGestureRecognizer:pan];

    [glass.contentView addSubview:self.btn];
    [self.window addSubview:glass];
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

- (void)openPanel {
    if (self.dragging) return;

    NSString *msg = [NSString stringWithFormat:@"%@\n\n%@", realDeviceInfo(), fakeDeviceInfo()];

    UIAlertController *a =
    [UIAlertController alertControllerWithTitle:@"Device Panel"
                                        message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"🔄 Regenerate IDs"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * _Nonnull action) {
        regenerateIDs();
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"🧹 Full Reset App Data"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * _Nonnull action) {
        fullResetAppData();
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Close"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

    [topVC() presentViewController:a animated:YES completion:nil];
}

@end

#pragma mark - INIT

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [Bubble shared];
    });
}
