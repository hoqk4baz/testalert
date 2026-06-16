#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>

#pragma mark - Helpers

static NSString *randomUUID(void) {
    return [[NSUUID UUID] UUIDString];
}

static NSString *fakeIDKey = @"fake.idfa.uuid";
static NSString *fakeIDFVKey = @"fake.idfv.uuid";

static NSString *getOrCreateFake(NSString *key) {
    NSString *val = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (!val) {
        val = randomUUID();
        [[NSUserDefaults standardUserDefaults] setObject:val forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return val;
}

static void regenerateFakeIDs(void) {
    [[NSUserDefaults standardUserDefaults] setObject:randomUUID() forKey:fakeIDKey];
    [[NSUserDefaults standardUserDefaults] setObject:randomUUID() forKey:fakeIDFVKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - UIWindow helper

static UIViewController *topController(void) {
    UIWindow *window = nil;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {

            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) {
                    window = w;
                    break;
                }
            }
        }
    }

    return window.rootViewController;
}

#pragma mark - Hooks (IMPORTANT FIX)

%hook UIDevice

- (NSUUID *)identifierForVendor {
    NSString *fake = getOrCreateFake(fakeIDFVKey);
    return [[NSUUID alloc] initWithUUIDString:fake];
}

%end

#pragma mark - Ad ID Hook

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    NSString *fake = getOrCreateFake(fakeIDKey);
    return [[NSUUID alloc] initWithUUIDString:fake];
}

%end

#pragma mark - Floating Bubble

@interface DeviceSpooferBubble : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, assign) BOOL isDragging;
@end

@implementation DeviceSpooferBubble

+ (instancetype)shared {
    static DeviceSpooferBubble *s;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[self alloc] init];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup {

    UIWindowScene *scene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;

    self.window = [[UIWindow alloc] initWithWindowScene:scene];
    self.window.frame = CGRectMake(250, 120, 70, 70);
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = UIColor.clearColor;

    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    // Blur container
    UIVisualEffectView *blur =
    [[UIVisualEffectView alloc] initWithEffect:
     [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];

    blur.frame = CGRectMake(0, 0, 70, 70);
    blur.layer.cornerRadius = 35;
    blur.clipsToBounds = YES;

    // Button
    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    self.button.frame = blur.bounds;

    UIImageSymbolConfiguration *cfg =
    [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightBold];

    UIImage *img =
    [UIImage systemImageNamed:@"arrow.triangle.2.circlepath.circle.fill"
            withConfiguration:cfg];

    [self.button setImage:img forState:UIControlStateNormal];
    self.button.tintColor = UIColor.systemBlueColor;

    [self.button addTarget:self action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];

    // Gesture (FIX: tap + drag conflict solved)
    UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    pan.cancelsTouchesInView = NO;

    [self.button addGestureRecognizer:pan];

    [blur.contentView addSubview:self.button];
    [self.window addSubview:blur];
}

- (void)pan:(UIPanGestureRecognizer *)g {

    CGPoint t = [g translationInView:self.window];
    CGPoint center = self.window.center;

    center.x += t.x;
    center.y += t.y;

    self.window.center = center;
    [g setTranslation:CGPointZero inView:self.window];

    if (g.state == UIGestureRecognizerStateBegan) {
        self.isDragging = YES;
    }

    if (g.state == UIGestureRecognizerStateEnded) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.15 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            self.isDragging = NO;
        });
    }
}

- (void)tap {
    if (self.isDragging) return;

    UIDevice *dev = UIDevice.currentDevice;
    ASIdentifierManager *ad = [ASIdentifierManager sharedManager];

    NSString *msg = [NSString stringWithFormat:
                     @"IDFV: %@\nIDFA: %@\nModel: %@\nSystem: %@ %@\nName: %@",
                     dev.identifierForVendor.UUIDString,
                     ad.advertisingIdentifier.UUIDString,
                     dev.model,
                     dev.systemName,
                     dev.systemVersion,
                     dev.name];

    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Device Info"
                                        message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *regen =
    [UIAlertAction actionWithTitle:@"🔄 Yenile"
                             style:UIAlertActionStyleDestructive
                           handler:^(UIAlertAction * _Nonnull action) {
        regenerateFakeIDs();
    }];

    UIAlertAction *close =
    [UIAlertAction actionWithTitle:@"Kapat"
                             style:UIAlertActionStyleCancel
                           handler:nil];

    [alert addAction:regen];
    [alert addAction:close];

    [topController() presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Init

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [DeviceSpooferBubble shared];
    });
}
