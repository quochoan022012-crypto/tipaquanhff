// ModMenuViewController.mm — Giao diện mới như ảnh yêu cầu
#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPPrefs.h"
#import "../esp/drawing_view/menu.h"
#import "../mahoa.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const CGFloat kPanelWidth    = 320.0f;
static const CGFloat kPanelHeight   = 400.0f;
static const CGFloat kHeaderHeight  = 50.0f;
static const CGFloat kTopTabHeight  = 40.0f;
static const CGFloat kRowHeight     = 42.0f;
static const CGFloat kCheckboxSize  = 22.0f;

// Màu sắc theo ảnh mẫu (nền tối, chữ trắng, checkbox xanh)
#define kColorBG          [UIColor colorWithRed:0.08f green:0.08f blue:0.12f alpha:0.95f]
#define kColorHeader      [UIColor colorWithRed:0.05f green:0.05f blue:0.08f alpha:1.0f]
#define kColorTabBar      [UIColor colorWithRed:0.12f green:0.12f blue:0.18f alpha:1.0f]
#define kColorTabActive   [UIColor colorWithRed:0.20f green:0.20f blue:0.28f alpha:1.0f]
#define kColorTabText     [UIColor colorWithWhite:0.6f alpha:1.0f]
#define kColorTabTextActive [UIColor whiteColor]
#define kColorRowBG       [UIColor colorWithRed:0.10f green:0.10f blue:0.16f alpha:1.0f]
#define kColorText        [UIColor colorWithWhite:0.95f alpha:1.0f]
#define kColorSeparator   [UIColor colorWithWhite:0.2f alpha:1.0f]
#define kColorCheckOn     [UIColor colorWithRed:0.0f green:0.75f blue:0.4f alpha:1.0f]
#define kColorCheckBorder [UIColor colorWithWhite:0.4f alpha:1.0f]
#define kColorCheckOff    [UIColor colorWithWhite:0.2f alpha:1.0f]
#define kColorSectionText [UIColor colorWithRed:0.0f green:0.75f blue:0.4f alpha:1.0f]

typedef NS_ENUM(NSInteger, MenuTab) {
    MenuTabESP    = 0,
    MenuTabAimbot = 1,
    MenuTabKhac   = 2,
};

@interface ModMenuViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) MenuTab currentTab;
@property (nonatomic, strong) UIView *floatingPanel;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentContainer;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, assign) NSInteger trackingPointerId;
@property (nonatomic, assign) BOOL menuDragging;
@property (nonatomic, assign) CGPoint menuDragStartOrigin;
@property (nonatomic, assign) CGPoint menuDragStartTouch;
@property (nonatomic, copy) void (^onCloseBlock)(void);
@property (nonatomic, copy) void (^onExitHUDRequested)(void);
@end

@implementation ModMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.multipleTouchEnabled = YES;
    _trackingPointerId = -1;
    _currentTab = MenuTabESP;
    _tabButtons = [NSMutableArray array];
    
    [self setupFloatingPanel];
    [self setupHeaderBar];
    [self setupTopTabBar];
    [self setupContentArea];
    [self loadTabContent:_currentTab];
}

- (void)setupFloatingPanel {
    CGPoint pos = [self loadPanelPosition];
    _floatingPanel = [[UIView alloc] initWithFrame:
        CGRectMake(pos.x, pos.y, kPanelWidth, kPanelHeight)];
    _floatingPanel.backgroundColor = kColorBG;
    _floatingPanel.layer.cornerRadius = 16.0f;
    _floatingPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    _floatingPanel.layer.shadowOpacity = 0.7f;
    _floatingPanel.layer.shadowRadius = 24.0f;
    _floatingPanel.layer.shadowOffset = CGSizeMake(0, 8);
    _floatingPanel.layer.masksToBounds = NO;
    _floatingPanel.layer.borderWidth = 0.5f;
    _floatingPanel.layer.borderColor = [UIColor colorWithWhite:0.3f alpha:0.3f].CGColor;
    [self.view addSubview:_floatingPanel];
}

- (CGPoint)loadPanelPosition {
    CGFloat x = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingPanelX"];
    CGFloat y = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingPanelY"];
    if (x <= 10.0f && y <= 10.0f) {
        CGRect s = [UIScreen mainScreen].bounds;
        x = (s.size.width - kPanelWidth) / 2.0f;
        y = 80.0f;
    }
    return CGPointMake(x, y);
}

// ─── HEADER ──────────────────────────────────
- (void)setupHeaderBar {
    UIView *hdr = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, kHeaderHeight)];
    hdr.backgroundColor = kColorHeader;
    hdr.layer.cornerRadius = 16.0f;
    hdr.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [_floatingPanel addSubview:hdr];
    
    // Icon game
    if (@available(iOS 13.0, *)) {
        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(14, 13, 24, 24)];
        icon.image = [UIImage systemImageNamed:@"gamecontroller.fill"];
        icon.tintColor = [UIColor colorWithRed:0.0f green:0.75f blue:0.4f alpha:1.0f];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        [hdr addSubview:icon];
    }
    
    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(44, 0, kPanelWidth - 100, kHeaderHeight)];
    title.text = @"Quanh External - Free Fire";
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    [hdr addSubview:title];
    
    // Nút đóng
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(kPanelWidth - 44, 8, 32, 32);
    close.backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.2f];
    close.layer.cornerRadius = 16.0f;
    if (@available(iOS 13.0, *)) {
        UIImage *x = [UIImage systemImageNamed:@"xmark"];
        [close setImage:x forState:UIControlStateNormal];
    } else {
        [close setTitle:@"✕" forState:UIControlStateNormal];
    }
    close.tintColor = [UIColor colorWithWhite:0.6f alpha:1.0f];
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [hdr addSubview:close];
}

// ─── TAB BAR ─────────────────────────────────
- (void)setupTopTabBar {
    UIView *tabBar = [[UIView alloc] initWithFrame:
        CGRectMake(0, kHeaderHeight, kPanelWidth, kTopTabHeight)];
    tabBar.backgroundColor = kColorTabBar;
    [_floatingPanel addSubview:tabBar];
    
    NSArray *titles = @[@"ESP", @"AIMBOT", @"KHÁC"];
    NSInteger n = titles.count;
    CGFloat tabW = kPanelWidth / (CGFloat)n;
    
    for (NSInteger i = 0; i < n; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(tabW * i, 0, tabW, kTopTabHeight);
        btn.tag = i;
        BOOL active = (i == _currentTab);
        
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:active ? UIFontWeightBold : UIFontWeightMedium];
        [btn setTitleColor:active ? kColorTabTextActive : kColorTabText forState:UIControlStateNormal];
        btn.backgroundColor = active ? kColorTabActive : [UIColor clearColor];
        
        if (active) {
            UIView *indicator = [[UIView alloc] initWithFrame:
                CGRectMake(tabW * 0.3f, kTopTabHeight - 3, tabW * 0.4f, 3)];
            indicator.backgroundColor = kColorSectionText;
            indicator.layer.cornerRadius = 1.5f;
            indicator.tag = 9999;
            [btn addSubview:indicator];
        }
        
        [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [tabBar addSubview:btn];
        [_tabButtons addObject:btn];
    }
}

// ─── CONTENT AREA ────────────────────────────
- (void)setupContentArea {
    CGFloat topY = kHeaderHeight + kTopTabHeight;
    CGFloat contentH = kPanelHeight - topY;
    
    UIView *contentClip = [[UIView alloc] initWithFrame:CGRectMake(0, topY, kPanelWidth, contentH)];
    contentClip.backgroundColor = [UIColor clearColor];
    contentClip.clipsToBounds = YES;
    [_floatingPanel addSubview:contentClip];
    
    _contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, contentH)];
    _contentScrollView.backgroundColor = [UIColor clearColor];
    _contentScrollView.showsVerticalScrollIndicator = NO;
    _contentScrollView.bounces = YES;
    [contentClip addSubview:_contentScrollView];
    
    _contentContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, contentH)];
    _contentContainer.backgroundColor = [UIColor clearColor];
    [_contentScrollView addSubview:_contentContainer];
}

// ─── CHECKBOX ─────────────────────────────────
- (UIView *)makeCheckboxWithState:(BOOL)checked {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kCheckboxSize, kCheckboxSize)];
    box.backgroundColor = checked ? kColorCheckOn : kColorCheckOff;
    box.layer.cornerRadius = 4.0f;
    box.layer.borderWidth = 1.5f;
    box.layer.borderColor = checked ? kColorCheckOn.CGColor : kColorCheckBorder.CGColor;
    box.tag = checked ? 1 : 0;
    
    if (checked && @available(iOS 13.0, *)) {
        UIImageView *check = [[UIImageView alloc] initWithFrame:CGRectMake(3, 3, 16, 16)];
        check.image = [UIImage systemImageNamed:@"checkmark"];
        check.tintColor = [UIColor whiteColor];
        check.contentMode = UIViewContentModeScaleAspectFit;
        check.tag = 9999;
        [box addSubview:check];
    }
    return box;
}

- (UIView *)buildCheckboxRowWithTitle:(NSString *)title key:(NSString *)key {
    BOOL on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, kRowHeight)];
    row.backgroundColor = kColorRowBG;
    row.tag = 100;
    objc_setAssociatedObject(row, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Checkbox bên trái
    UIView *cb = [self makeCheckboxWithState:on];
    cb.frame = CGRectMake(16, (kRowHeight - kCheckboxSize) / 2.0f, kCheckboxSize, kCheckboxSize);
    cb.tag = 200;
    objc_setAssociatedObject(cb, "isCheckbox", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [row addSubview:cb];
    
    // Label
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16 + kCheckboxSize + 12, 0, kPanelWidth - 60, kRowHeight)];
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    lbl.textColor = kColorText;
    [row addSubview:lbl];
    
    // Separator
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(16, kRowHeight - 0.5, kPanelWidth - 32, 0.5)];
    sep.backgroundColor = kColorSeparator;
    [row addSubview:sep];
    
    return row;
}

// ─── LOAD TAB CONTENT ─────────────────────────
- (void)loadTabContent:(MenuTab)tab {
    for (UIView *v in _contentContainer.subviews) [v removeFromSuperview];
    _contentScrollView.contentOffset = CGPointZero;
    
    CGFloat y = 0;
    CGFloat w = kPanelWidth;
    
    if (tab == MenuTabESP) {
        y = [self addSectionTitle:@"ESP" atY:y width:w];
        NSArray *items = @[
            @[@"ESP ĐƯỜNG KẺ", @"Line"],
            @[@"ESP HỘP", @"Box"],
            @[@"ESP MÁU", @"Health"],
            @[@"ESP TÊN", @"Name"],
            @[@"ESP SỐ LƯỢNG", @"Count"]
        ];
        y = [self addCheckboxRows:items atY:y width:w];
        
    } else if (tab == MenuTabAimbot) {
        y = [self addSectionTitle:@"AIMBOT" atY:y width:w];
        NSArray *items = @[
            @[@"Bật Aimbot", @"Aimbot"],
            @[@"Rage Aimbot", @"AimRage"],
            @[@"Đường Aim", @"LineAim"]
        ];
        y = [self addCheckboxRows:items atY:y width:w];
        
    } else if (tab == MenuTabKhac) {
        y = [self addSectionTitle:@"KHÁC" atY:y width:w];
        NSArray *items = @[
            @[@"Vô hạn đạn", @"VohaDan"],
            @[@"Bắn nhanh", @"FastFire"],
            @[@"Cam cao", @"camcao"],
            @[@"Không cần reload", @"NoReLoad"]
        ];
        y = [self addCheckboxRows:items atY:y width:w];
    }
    
    // Nút LƯU CÀI ĐẶT
    y += 8;
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(20, y, w - 40, 40);
    saveBtn.backgroundColor = kColorCheckOn;
    saveBtn.layer.cornerRadius = 8.0f;
    [saveBtn setTitle:@"LƯU CÀI ĐẶT" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [saveBtn addTarget:self action:@selector(saveSettingsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_contentContainer addSubview:saveBtn];
    y += 48;
    
    _contentContainer.frame = CGRectMake(0, 0, w, y + 10);
    _contentScrollView.contentSize = _contentContainer.frame.size;
}

- (CGFloat)addSectionTitle:(NSString *)title atY:(CGFloat)y width:(CGFloat)w {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 6, w - 32, 22)];
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    lbl.textColor = kColorSectionText;
    [_contentContainer addSubview:lbl];
    return y + 32;
}

- (CGFloat)addCheckboxRows:(NSArray *)items atY:(CGFloat)y width:(CGFloat)w {
    for (NSArray *item in items) {
        UIView *row = [self buildCheckboxRowWithTitle:item[0] key:item[1]];
        row.frame = CGRectMake(0, y, w, kRowHeight);
        [_contentContainer addSubview:row];
        y += kRowHeight;
    }
    return y;
}

// ─── ACTIONS ──────────────────────────────────
- (void)tabButtonTapped:(UIButton *)sender {
    MenuTab tab = (MenuTab)sender.tag;
    if (tab == _currentTab) return;
    _currentTab = tab;
    [self updateTabBarForTab:tab];
    [self loadTabContent:tab];
}

- (void)updateTabBarForTab:(MenuTab)tab {
    NSInteger n = _tabButtons.count;
    CGFloat tabW = kPanelWidth / (CGFloat)n;
    for (NSInteger i = 0; i < n; i++) {
        UIButton *btn = _tabButtons[i];
        BOOL active = (i == tab);
        btn.backgroundColor = active ? kColorTabActive : [UIColor clearColor];
        [btn setTitleColor:active ? kColorTabTextActive : kColorTabText forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:active ? UIFontWeightBold : UIFontWeightMedium];
        [[btn viewWithTag:9999] removeFromSuperview];
        if (active) {
            UIView *indicator = [[UIView alloc] initWithFrame:
                CGRectMake(tabW * 0.3f, kTopTabHeight - 3, tabW * 0.4f, 3)];
            indicator.backgroundColor = kColorSectionText;
            indicator.layer.cornerRadius = 1.5f;
            indicator.tag = 9999;
            [btn addSubview:indicator];
        }
    }
}

- (void)checkboxTapped:(UIView *)row {
    NSString *key = objc_getAssociatedObject(row, "key");
    if (!key) return;
    
    UIView *cb = nil;
    for (UIView *v in row.subviews) {
        if (objc_getAssociatedObject(v, "isCheckbox")) {
            cb = v;
            break;
        }
    }
    if (!cb) return;
    
    BOOL newState = (cb.tag == 0);
    cb.tag = newState ? 1 : 0;
    cb.backgroundColor = newState ? kColorCheckOn : kColorCheckOff;
    cb.layer.borderColor = newState ? kColorCheckOn.CGColor : kColorCheckBorder.CGColor;
    [[cb viewWithTag:9999] removeFromSuperview];
    
    if (newState && @available(iOS 13.0, *)) {
        UIImageView *check = [[UIImageView alloc] initWithFrame:CGRectMake(3, 3, 16, 16)];
        check.image = [UIImage systemImageNamed:@"checkmark"];
        check.tintColor = [UIColor whiteColor];
        check.contentMode = UIViewContentModeScaleAspectFit;
        check.tag = 9999;
        [cb addSubview:check];
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:newState forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    ESPPrefsSetBool(key, newState);
    ESPSyncFromPrefs();
}

- (void)saveSettingsTapped {
    [[NSUserDefaults standardUserDefaults] synchronize];
    ESPSyncFromPrefs();
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅"
                                                                   message:@"Đã lưu cài đặt!"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeTapped {
    [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.x forKey:@"FloatingPanelX"];
    [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.y forKey:@"FloatingPanelY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (self.onCloseBlock) self.onCloseBlock();
}

// ─── TOUCH HANDLING ──────────────────────────
- (BOOL)handleTouchAtViewPoint:(CGPoint)point phase:(NSInteger)phase pointerId:(NSInteger)pointerId {
    BOOL inside = CGRectContainsPoint(_floatingPanel.frame, point);
    UITouchPhase ph = (UITouchPhase)phase;
    
    if (ph == UITouchPhaseBegan) {
        if (!inside) return NO;
        if (_trackingPointerId != -1 && _trackingPointerId != pointerId) return NO;
        _trackingPointerId = pointerId;
        _menuDragging = NO;
        
        CGPoint ip = CGPointMake(point.x - _floatingPanel.frame.origin.x,
                                 point.y - _floatingPanel.frame.origin.y);
        
        if (ip.y < kHeaderHeight) {
            _menuDragging = YES;
            _menuDragStartOrigin = _floatingPanel.frame.origin;
            _menuDragStartTouch = point;
            return YES;
        }
        
        if (ip.y > kHeaderHeight + kTopTabHeight) {
            CGPoint cp = CGPointMake(ip.x, ip.y - kHeaderHeight - kTopTabHeight + _contentScrollView.contentOffset.y);
            for (UIView *row in _contentContainer.subviews) {
                if (row.tag == 100 && CGRectContainsPoint(row.frame, cp)) {
                    objc_setAssociatedObject(self, "selectedRow", row, OBJC_ASSOCIATION_ASSIGN);
                    return YES;
                }
            }
        }
        return YES;
    }
    
    if (ph == UITouchPhaseEnded || ph == UITouchPhaseCancelled) {
        if (pointerId != _trackingPointerId) return NO;
        if (!_menuDragging) {
            UIView *row = objc_getAssociatedObject(self, "selectedRow");
            if (row) {
                [self checkboxTapped:row];
                objc_setAssociatedObject(self, "selectedRow", nil, OBJC_ASSOCIATION_ASSIGN);
            }
        } else {
            [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.x forKey:@"FloatingPanelX"];
            [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.y forKey:@"FloatingPanelY"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        _trackingPointerId = -1;
        _menuDragging = NO;
        return YES;
    }
    
    if (ph == UITouchPhaseMoved && _menuDragging && pointerId == _trackingPointerId) {
        CGFloat dx = point.x - _menuDragStartTouch.x;
        CGFloat dy = point.y - _menuDragStartTouch.y;
        CGRect s = self.view.bounds;
        CGFloat nx = MAX(0, MIN(s.size.width - kPanelWidth, _menuDragStartOrigin.x + dx));
        CGFloat ny = MAX(0, MIN(s.size.height - kPanelHeight, _menuDragStartOrigin.y + dy));
        _floatingPanel.frame = CGRectMake(nx, ny, kPanelWidth, kPanelHeight);
        return YES;
    }
    
    return inside && pointerId == _trackingPointerId;
}

@end
