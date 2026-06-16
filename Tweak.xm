
#import <UIKit/UIKit.h>

static UIWindow *debugWindow;
static UITextView *logView;

@interface Logger : NSObject
+ (void)add:(NSString *)text;
@end

@implementation Logger

+ (void)setup {

    if (debugWindow) return;

    debugWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 340, 300)];
    debugWindow.windowLevel = UIWindowLevelAlert + 1000;
    debugWindow.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    debugWindow.hidden = NO;

    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.clearColor;
    debugWindow.rootViewController = vc;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(10, 80, 320, 300)];
    panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    panel.layer.cornerRadius = 12;

    logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, 300, 280)];
    logView.backgroundColor = UIColor.clearColor;
    logView.textColor = UIColor.greenColor;
    logView.editable = NO;
    logView.font = [UIFont systemFontOfSize:12];

    [panel addSubview:logView];
    [vc.view addSubview:panel];
}

+ (void)add:(NSString *)text {

    dispatch_async(dispatch_get_main_queue(), ^{
        [self setup];

        NSString *old = logView.text ?: @"";
        NSString *newText = [old stringByAppendingFormat:@"\n%@", text];

        logView.text = newText;

        NSRange bottom = NSMakeRange(newText.length, 1);
        [logView scrollRangeToVisible:bottom];
    });
}

@end
