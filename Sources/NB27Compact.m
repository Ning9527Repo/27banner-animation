#import "NB27Compact.h"
#import "NB27CompactState.h"
#import "NB27Diagnostics.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>
#include <float.h>
#include <math.h>

/* Model geometry only. No system view/layer is ever mutated. */
@interface NB27CompactWindow : UIWindow
@property(nonatomic) CGRect expectedScreen, expectedScene;
@end
@implementation NB27CompactWindow
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e { (void)p; (void)e; return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { (void)p; (void)e; return nil; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!CGRectEqualToRect(self.screen.bounds, self.expectedScreen) ||
        !CGRectEqualToRect(self.windowScene.coordinateSpace.bounds, self.expectedScene) ||
        self.windowScene.interfaceOrientation != UIInterfaceOrientationPortrait) self.hidden = YES;
}
@end
@interface NB27CompactWatch : NSObject
- (void)changed:(NSNotification *)note;
- (void)tick:(NSTimer *)timer;
@end
static NB27CompactState State;
static BOOL Requested, HaveAnchor;
static __weak UIWindowScene *Scene;
static UIScreen *Screen;
static CGRect ScreenBounds, SceneBounds, Bar, CacheBar, Line, SourceBounds;
static __weak UIView *Reference, *TimeItem;
static __weak UIView *TimeLabel; // Native status strings need not inherit UILabel.
static __weak UIWindow *SourceWindow;
static UIColor *Ink;
static NB27CompactWindow *Window;
static CALayer *Stroke;
static NSTimer *Timer;
static NB27CompactWatch *Watch;
static CFTimeInterval LastScan = -DBL_MAX;
static void CompactRefresh(void);

static BOOL CompactRect(CGRect r) {
    return isfinite(r.origin.x) && isfinite(r.origin.y) &&
        isfinite(r.size.width) && isfinite(r.size.height) && r.size.width > 0 && r.size.height > 0;
}
static BOOL CompactSpringBoard(void) {
    return [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"];
}
static void CompactDiagnostic(void) {
    static unsigned count;
    if (count < 4) { ++count; NSLog(@"[NB27Compact] native time anchor unavailable; hidden"); }
}
static void CompactClearAnchor(void) {
    HaveAnchor = NO; TimeItem = nil; TimeLabel = nil; SourceWindow = nil; Ink = nil;
    if (Window) Window.hidden = YES;
}
static void CompactDropWindow(void) {
    Window.hidden = YES; Window = nil; Stroke = nil;
}
static BOOL CompactAllowed(void) {
    BOOL allowed = Requested && CompactSpringBoard() && !UIAccessibilityIsReduceMotionEnabled();
    NB27CompactStateEnable(&State, allowed);
    if (!allowed) {
        CompactClearAnchor(); CompactDropWindow(); [Timer invalidate]; Timer = nil;
    }
    return allowed;
}
/* Reject forwarding, extra arguments and ABI-unknown return types before messaging. */
static char CompactReturn(Method m) {
    if (!m || method_getNumberOfArguments(m) != 2) return 0;
    char a[8] = {0}, b[8] = {0}, r[8] = {0};
    method_getArgumentType(m, 0, a, sizeof(a)); method_getArgumentType(m, 1, b, sizeof(b));
    method_getReturnType(m, r, sizeof(r));
    return ((a[0] == '@' || a[0] == '#') && !a[1] && b[0] == ':' && !b[1] && !r[1]) ? r[0] : 0;
}
static BOOL CompactUnlocked(void) {
    Class cls = NSClassFromString(@"SBLockScreenManager");
    SEL shared = NSSelectorFromString(@"sharedInstance"), locked = NSSelectorFromString(@"isUILocked");
    if (!cls || CompactReturn(class_getClassMethod(cls, shared)) != '@') return NO;
    @try {
        id manager = ((id (*)(id, SEL))objc_msgSend)(cls, shared);
        if (!manager || ![manager isKindOfClass:cls]) return NO;
        char type = CompactReturn(class_getInstanceMethod(object_getClass(manager), locked));
        if (type == 'B') return !((bool (*)(id, SEL))objc_msgSend)(manager, locked);
        if (type == 'c') return !((signed char (*)(id, SEL))objc_msgSend)(manager, locked);
    } @catch (NSException *exception) { (void)exception; }
    return NO;
}
static BOOL CompactVisible(UIView *v) {
    UIWindow *w = v.window;
    for (unsigned depth = 0; v && depth < 16; ++depth, v = v.superview) {
        if (v.hidden || !isfinite(v.alpha) || v.alpha <= .01) return NO;
        if (v == w) return YES;
    }
    return NO;
}
static UIColor *CompactTextColor(UIView *view) {
    if ([view isKindOfClass:UILabel.class]) return ((UILabel *)view).textColor;
    Class cls = NSClassFromString(@"_UIStatusBarStringView");
    SEL selector = NSSelectorFromString(@"textColor");
    if (!cls || ![view isKindOfClass:cls] ||
        CompactReturn(class_getInstanceMethod(object_getClass(view), selector)) != '@') return nil;
    @try {
        id value = ((id (*)(id, SEL))objc_msgSend)(view, selector);
        return [value isKindOfClass:UIColor.class] ? value : nil;
    } @catch (NSException *exception) { (void)exception; return nil; }
}
static BOOL CompactCapture(UIView *item, UIView *label) {
    UIWindow *w = item.window;
    if (!w || w == Window || w.screen != Screen || label.window != w ||
        !CompactVisible(item) || !CompactVisible(label)) return NO;
    UIView *ancestor = label;
    for (unsigned n = 0; ancestor && ancestor != item && n < 5; ++n) ancestor = ancestor.superview;
    if (ancestor != item) return NO;
    UIWindowScene *sourceScene = w.windowScene;
    if (sourceScene && (sourceScene.interfaceOrientation != UIInterfaceOrientationPortrait ||
        sourceScene.screen != Screen || !CGRectEqualToRect(sourceScene.coordinateSpace.bounds, SceneBounds))) return NO;
    CGRect i = [item convertRect:item.bounds toCoordinateSpace:Screen.coordinateSpace];
    CGRect l = [label convertRect:label.bounds toCoordinateSpace:Screen.coordinateSpace];
    if (!CompactRect(i) || !CompactRect(l) ||
        !CGRectContainsRect(CGRectInset(Bar, -.5, -.5), i) ||
        !CGRectContainsRect(CGRectInset(i, -.5, -.5), l) ||
        l.size.width < l.size.height * .8 || i.size.width > ScreenBounds.size.width * .45) return NO;
    CGRect line = CGRectMake(CGRectGetMinX(i), CGRectGetMaxY(Bar) - 4,
                             i.size.width, 2); /* center 3pt above bar bottom; reference ~5px at 946px width */
    if (CGRectGetMinY(line) < CGRectGetMaxY(l) || !CGRectContainsRect(Bar, line)) return NO;
    UIColor *color = [CompactTextColor(label) resolvedColorWithTraitCollection:label.traitCollection];
    if (!color || !color.CGColor) return NO;
    CGFloat alpha = CGColorGetAlpha(color.CGColor);
    if (!isfinite(alpha) || alpha <= 0 || alpha > 1) return NO;
    TimeItem = item; TimeLabel = label; SourceWindow = w;
    SourceBounds = sourceScene ? sourceScene.coordinateSpace.bounds : CGRectZero;
    Line = line; CacheBar = Bar; Ink = [color colorWithAlphaComponent:alpha * .55]; HaveAnchor = YES;
    return YES;
}
static BOOL CompactLabels(UIView *v, UIView *item, unsigned depth, NSUInteger *budget) {
    if (!v || depth > 4 || !*budget) return NO;
    --*budget;
    if (v.hidden || v.alpha <= .01) return NO;
    Class nativeString = NSClassFromString(@"_UIStatusBarStringView");
    if (([v isKindOfClass:UILabel.class] || (nativeString && [v isKindOfClass:nativeString])) &&
        CompactCapture(item, v)) return YES;
    for (UIView *child in v.subviews) {
        if (!*budget) break;
        if (CompactLabels(child, item, depth + 1, budget)) return YES;
    }
    return NO;
}
static BOOL CompactTree(UIView *v, Class cls, unsigned depth, NSUInteger *budget) {
    if (!v || depth > 12 || !*budget) return NO;
    --*budget;
    if (v.hidden || v.alpha <= .01) return NO;
    if ([v isKindOfClass:cls]) return CompactLabels(v, v, 0, budget);
    for (UIView *child in v.subviews) {
        if (!*budget) break;
        if (CompactTree(child, cls, depth + 1, budget)) return YES;
    }
    return NO;
}
static BOOL CompactScan(void) {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - LastScan < 2) return NO;
    LastScan = now;
    Class cls = NSClassFromString(@"_UIStatusBarTimeItemView");
    if (!cls) { CompactDiagnostic(); return NO; }
    NSMutableArray<UIWindow *> *windows = [NSMutableArray new];
    unsigned scenes = 0;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if (++scenes > 8 || windows.count >= 24) break;
        if (![s isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws = (UIWindowScene *)s;
        if (ws.screen != Screen) continue;
        for (UIWindow *w in ws.windows) {
            if (windows.count >= 24) break;
            if (![windows containsObject:w]) [windows addObject:w];
        }
    }
    /* Legacy SpringBoard windows, still strictly this process. */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (windows.count >= 24) break;
        if (![windows containsObject:w]) [windows addObject:w];
    }
#pragma clang diagnostic pop
    NSUInteger budget = 384;
    for (UIWindow *w in windows) {
        if (!budget) break;
        if (w == Window || [w isKindOfClass:NB27CompactWindow.class] || w.screen != Screen) continue;
        if (CompactTree(w, cls, 0, &budget)) return YES;
    }
    if (!HaveAnchor) CompactDiagnostic();
    return NO;
}
static BOOL CompactContext(UIView *card) {
    if (!CompactAllowed() || UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone ||
        !CompactUnlocked()) return NO;
    UIWindowScene *scene = card ? card.window.windowScene : (Reference.window.windowScene ?: Scene);
    UIScreen *screen = scene.screen;
    if (!scene || screen != UIScreen.mainScreen ||
        scene.activationState != UISceneActivationStateForegroundActive ||
        scene.interfaceOrientation != UIInterfaceOrientationPortrait) return NO;
    CGRect sb = screen.coordinateSpace.bounds, cb = scene.coordinateSpace.bounds;
    if (!CompactRect(sb) || !CompactRect(cb) || sb.size.width >= sb.size.height ||
        !CGRectEqualToRect(sb, [scene.coordinateSpace convertRect:cb toCoordinateSpace:screen.coordinateSpace])) return NO;
    if (Screen != screen || Scene != scene || !CGRectEqualToRect(sb, ScreenBounds) ||
        !CGRectEqualToRect(cb, SceneBounds)) {
        BOOL existed = Screen != nil;
        BOOL sameGeometry = Screen == screen && CGRectEqualToRect(sb, ScreenBounds) && CGRectEqualToRect(cb, SceneBounds);
        CompactDropWindow();
        if (!sameGeometry) CompactClearAnchor();
        Screen = screen; Scene = scene; ScreenBounds = sb; SceneBounds = cb;
        if (existed) return NO;
    }
    UIStatusBarManager *manager = scene.statusBarManager;
    Bar = manager.statusBarFrame; /* UIKit statusBarFrame is in screen coordinates. */
    if (!manager || manager.statusBarHidden || !CompactRect(Bar) ||
        !CGRectContainsRect(sb, Bar) || fabs(CGRectGetMinY(Bar) - CGRectGetMinY(sb)) > .5 ||
        Bar.size.height > sb.size.height * .15) { CompactClearAnchor(); return NO; }
    if (HaveAnchor && !CGRectEqualToRect(CacheBar, Bar)) CompactClearAnchor();
    UIWindow *source = SourceWindow;
    if (HaveAnchor && source && (source.screen != screen ||
        (source.windowScene && (!CGRectEqualToRect(source.windowScene.coordinateSpace.bounds, SourceBounds) ||
         source.windowScene.interfaceOrientation != UIInterfaceOrientationPortrait)))) CompactClearAnchor();
    if (HaveAnchor && (!TimeItem || !TimeLabel || !source ||
        !CompactCapture(TimeItem, TimeLabel))) CompactClearAnchor();
    if (!HaveAnchor) CompactScan();
    return HaveAnchor;
}
static void CompactShow(void) {
    if (!Window) {
        Window = [[NB27CompactWindow alloc] initWithWindowScene:Scene];
        Window.frame = SceneBounds; Window.expectedScreen = ScreenBounds; Window.expectedScene = SceneBounds;
        Window.windowLevel = UIWindowLevelStatusBar + 1; Window.backgroundColor = UIColor.clearColor;
        Window.opaque = NO; Window.userInteractionEnabled = NO; Window.accessibilityElementsHidden = YES;
        UIViewController *root = [UIViewController new];
        root.view = [[UIView alloc] initWithFrame:Window.bounds];
        root.view.backgroundColor = UIColor.clearColor; root.view.opaque = NO;
        root.view.userInteractionEnabled = NO; root.view.accessibilityElementsHidden = YES;
        Window.rootViewController = root; Stroke = [CALayer layer];
        Stroke.cornerRadius = 1; [root.view.layer addSublayer:Stroke];
    }
    CGRect local = [Window.rootViewController.view convertRect:Line fromCoordinateSpace:Screen.coordinateSpace];
    if (!CompactRect(local) || !CGRectContainsRect(Window.bounds, local)) { Window.hidden = YES; return; }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    Stroke.frame = local; Stroke.backgroundColor = Ink.CGColor; [CATransaction commit];
    Window.hidden = NO; /* Never makeKey, never write any other window/root. */
}
static void CompactTimer(void) {
    BOOL need = State.enabled && (State.retained || State.pending);
    if (!need) { [Timer invalidate]; Timer = nil; return; }
    if (!Timer) {
        Timer = [NSTimer timerWithTimeInterval:1 target:Watch selector:@selector(tick:) userInfo:nil repeats:YES];
        Timer.tolerance = .2; [NSRunLoop.mainRunLoop addTimer:Timer forMode:NSRunLoopCommonModes];
    }
}
static void CompactRefresh(void) {
    if (Window) Window.hidden = YES;
    if (State.retained && CompactContext(nil)) CompactShow();
    else CompactAllowed();
    CompactTimer();
}
@implementation NB27CompactWatch
- (void)changed:(NSNotification *)note {
    (void)note;
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self changed:nil]; }); return;
    }
    CompactClearAnchor();
    CompactAllowed(); /* Reduce Motion clears, even before the low-frequency tick. */
    CompactTimer();
}
- (void)tick:(NSTimer *)timer { (void)timer; CompactRefresh(); }
@end
static void CompactObserve(void) {
    if (Watch || !CompactSpringBoard()) return;
    Watch = [NB27CompactWatch new];
    // Event-driven hiding complements the low-frequency safety recheck. No
    // lock manager setter, system layer mutation, or private observer hook.
    static int lockToken = -1, displayToken = -1;
    notify_register_dispatch("com.apple.springboard.lockstate", &lockToken, dispatch_get_main_queue(),
        ^(int token) { (void)token; [Watch changed:nil]; });
    notify_register_dispatch("com.apple.iokit.hid.displayStatus", &displayToken, dispatch_get_main_queue(),
        ^(int token) { (void)token; [Watch changed:nil]; });
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (NSString *name in @[UIAccessibilityReduceMotionStatusDidChangeNotification,
        UIApplicationWillChangeStatusBarOrientationNotification, UIApplicationDidChangeStatusBarOrientationNotification,
        UIApplicationDidChangeStatusBarFrameNotification, UIScreenModeDidChangeNotification,
        UISceneWillDeactivateNotification, UISceneDidActivateNotification, UISceneDidDisconnectNotification])
        [NSNotificationCenter.defaultCenter addObserver:Watch selector:@selector(changed:) name:name object:nil];
#pragma clang diagnostic pop
}
void NB27CompactSetEnabled(BOOL enabled) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ NB27CompactSetEnabled(enabled); }); return; }
    Requested = enabled; CompactObserve(); CompactRefresh();
}
void NB27CompactNoteEntrance(UIView *card) {
    if (!NSThread.isMainThread || !card) return;
    Reference = card; CompactObserve();
    if (!CompactContext(card) && Window) Window.hidden = YES;
}
BOOL NB27CompactOriginForCard(UIView *card, CGPoint *center, CGSize *size) {
    if (!NSThread.isMainThread || !card || !center || !size || !card.superview || !card.window) return NO;
    if (!CompactContext(card)) { if (Window) Window.hidden = YES; return NO; }
    UIView *parent = card.superview;
    if (card.layer.superlayer != parent.layer || !CompactRect(parent.bounds) || !CompactRect(card.bounds)) return NO;
    CGRect r = [parent convertRect:Line fromCoordinateSpace:Screen.coordinateSpace];
    CGPoint p = [parent convertPoint:CGPointMake(CGRectGetMidX(Line), CGRectGetMidY(Line))
                fromCoordinateSpace:Screen.coordinateSpace];
    if (!CompactRect(r) || !isfinite(p.x) || !isfinite(p.y)) return NO;
    CGPoint back = [parent convertPoint:p toCoordinateSpace:Screen.coordinateSpace];
    if (!isfinite(back.x) || !isfinite(back.y) || fabs(back.x - CGRectGetMidX(Line)) > .5 ||
        fabs(back.y - CGRectGetMidY(Line)) > .5) return NO;
    Reference = card; *center = p; *size = r.size; return YES;
}
NSUInteger NB27CompactBeginExit(UIView *card) {
    if (!NSThread.isMainThread) return 0;
    CompactObserve(); CGPoint center; CGSize size;
    BOOL supported = NB27CompactOriginForCard(card, &center, &size);
    NSUInteger ticket = (NSUInteger)NB27CompactStateBegin(&State, supported);
    CompactTimer(); return ticket;
}
void NB27CompactFinishExit(NSUInteger ticket) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ NB27CompactFinishExit(ticket); }); return; }
    if (CompactAllowed() && NB27CompactStateFinish(&State, (uintptr_t)ticket)) CompactRefresh();
}
void NB27CompactAbortExit(NSUInteger ticket) {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ NB27CompactAbortExit(ticket); }); return; }
    if (CompactAllowed() && NB27CompactStateAbort(&State, (uintptr_t)ticket)) { CompactTimer(); CompactRefresh(); }
}
