#import "menu.h"
#import "icons.h"
#import "ModMenuViewController.h"
#import "ESPPrefs.h"
#import "esp.h"
#import "../../mahoa.h"
#import <UIKit/UIKit.h>

static const CGFloat kMenuButtonSize = 56.0f;
static const CGFloat kAccentR = 0.0f, kAccentG = 0.7f, kAccentB = 0.4f;

@interface MenuView ()
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) ModMenuViewController *presentedModMenu;
@property (nonatomic, assign) NSInteger trackingPointerId;
@property (nonatomic, assign) BOOL touchOnButton;
@property (nonatomic, assign) BOOL buttonDragging;
@property (nonatomic, assign) CGPoint buttonDragStartCenter;
@property (nonatomic, assign) CGPoint buttonDragStartPoint;
@end

@implementation MenuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        [self setupMenuButton];
    }
    return self;
}

- (void)setupMenuButton {
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(20, 100, kMenuButtonSize, kMenuButtonSize);
    _menuButton.backgroundColor = [UIColor colorWithRed:kAccentR green:kAccentG blue:kAccentB alpha:0.9f];
    _menuButton.layer.cornerRadius = kMenuButtonSize / 2.0f;
    _menuButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _menuButton.layer.shadowOpacity = 0.4f;
    _menuButton.layer.shadowRadius = 8.0f;
    _menuButton.layer.shadowOffset = CGSizeMake(0, 2);
    
    // Icon menu
    if (@available(iOS 13.0, *)) {
        UIImage *icon = [UIImage systemImageNamed:@"line.horizontal.3"];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
        icon = [icon imageByApplyingSymbolConfiguration:cfg];
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [_menuButton setImage:icon forState:UIControlStateNormal];
        _menuButton.tintColor = [UIColor whiteColor];
    } else {
        [_menuButton setTitle:@"M" forState:UIControlStateNormal];
        [_menuButton.titleLabel setFont:[UIFont boldSystemFontOfSize:20]];
        [_menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    
    [self addSubview:_menuButton];
    [self loadMenuButtonPosition];
}

- (void)loadMenuButtonPosition {
    CGFloat x = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingMenuBtnX"];
    CGFloat y = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingMenuBtnY"];
    if (x > 0 || y > 0) {
        _menuButton.frame = CGRectMake(x, y, kMenuButtonSize, kMenuButtonSize);
    }
}

- (UIViewController *)viewControllerForView:(UIView *)view {
    UIResponder *r = view;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = [r nextResponder];
    return [r isKindOfClass:[UIViewController class]] ? (UIViewController *)r : nil;
}

- (void)presentModMenu {
    UIViewController *parentVC = [self viewControllerForView:self];
    if (!parentVC) return;
    
    ModMenuViewController *vc = [[ModMenuViewController alloc] init];
    vc.view.frame = self.bounds;
    __weak MenuView *wself = self;
    vc.onCloseBlock = ^{
        [wself dismissModMenu];
    };
    vc.onExitHUDRequested = ^{
        if (wself.onExitHUDRequested) wself.onExitHUDRequested();
    };
    _presentedModMenu = vc;
    [parentVC addChildViewController:vc];
    [self addSubview:vc.view];
    [vc didMoveToParentViewController:parentVC];
    [self bringSubviewToFront:vc.view];
}

- (void)dismissModMenu {
    if (!_presentedModMenu) return;
    ModMenuViewController *vc = _presentedModMenu;
    _presentedModMenu = nil;
    [vc willMoveToParentViewController:nil];
    [vc.view removeFromSuperview];
    [vc removeFromParentViewController];
}

- (void)togglePanel {
    if (_presentedModMenu) {
        [self dismissModMenu];
        return;
    }
    [self presentModMenu];
}

- (BOOL)handleTouchAtWindowPoint:(CGPoint)windowPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    CGPoint local = [self convertPoint:windowPoint fromView:self.window];
    const CGFloat kInset = 12.0f;
    CGRect btnHit = CGRectInset(_menuButton.frame, -kInset, -kInset);
    BOOL insideBtn = CGRectContainsPoint(btnHit, local);
    
    if (_presentedModMenu) {
        CGPoint inMenuView = [self convertPoint:local toView:_presentedModMenu.view];
        if ([_presentedModMenu handleTouchAtViewPoint:inMenuView phase:(NSInteger)phase pointerId:pointerId])
            return YES;
        if (!insideBtn && phase == UITouchPhaseBegan) {
            [self dismissModMenu];
            return YES;
        }
    }
    
    switch (phase) {
        case UITouchPhaseBegan:
            if (insideBtn && !_touchOnButton) {
                _touchOnButton = YES;
                _buttonDragging = NO;
                _trackingPointerId = pointerId;
                _buttonDragStartCenter = _menuButton.center;
                _buttonDragStartPoint = local;
                return YES;
            }
            return NO;
            
        case UITouchPhaseMoved:
            if (_touchOnButton && pointerId == _trackingPointerId) {
                CGFloat dx = local.x - _buttonDragStartPoint.x;
                CGFloat dy = local.y - _buttonDragStartPoint.y;
                if (!_buttonDragging && (fabs(dx) + fabs(dy) > 12)) {
                    _buttonDragging = YES;
                }
                if (_buttonDragging) {
                    _menuButton.center = CGPointMake(_buttonDragStartCenter.x + dx, _buttonDragStartCenter.y + dy);
                    _buttonDragStartCenter = _menuButton.center;
                    _buttonDragStartPoint = local;
                }
                return YES;
            }
            return NO;
            
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled:
            if (_touchOnButton && pointerId == _trackingPointerId) {
                BOOL wasDrag = _buttonDragging;
                _touchOnButton = NO;
                _buttonDragging = NO;
                _trackingPointerId = -1;
                
                if (!wasDrag) {
                    [self togglePanel];
                } else {
                    [[NSUserDefaults standardUserDefaults] setFloat:_menuButton.frame.origin.x forKey:@"FloatingMenuBtnX"];
                    [[NSUserDefaults standardUserDefaults] setFloat:_menuButton.frame.origin.y forKey:@"FloatingMenuBtnY"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
                return YES;
            }
            return NO;
            
        default:
            return NO;
    }
}

- (BOOL)handleTouchAtLocalPoint:(CGPoint)localPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    return [self handleTouchAtWindowPoint:[self convertPoint:localPoint toView:self.window] phase:phase pointerId:pointerId];
}

- (void)reloadFloatingAuxButtonsFromPrefs {
    // Giữ nguyên
}

@end
