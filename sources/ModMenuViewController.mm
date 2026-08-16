// ModMenuViewController.mm — QHOANIOS redesign — Appreciate source
#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPPrefs.h"
#import "../esp/drawing_view/menu.h"
#import "../mahoa.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const CGFloat kPanelWidth    = 360.0f;
static const CGFloat kPanelHeight   = 310.0f;
static const CGFloat kHeaderHeight  = 40.0f;
static const CGFloat kTopTabHeight  = 36.0f;
static const CGFloat kRowHeight     = 40.0f;
static const CGFloat kScrollBarW    = 3.0f;
static const CGFloat kCheckboxSize  = 22.0f;

// Light theme — giống ảnh mẫu
#define kColorBG          [UIColor colorWithRed:0.95f green:0.95f blue:0.97f alpha:0.97f]
#define kColorHeader      [UIColor colorWithRed:0.13f green:0.13f blue:0.18f alpha:1.0f]
#define kColorTabBar      [UIColor colorWithRed:0.90f green:0.90f blue:0.93f alpha:1.0f]
#define kColorTabActive   [UIColor whiteColor]
#define kColorTabInactive [UIColor clearColor]
#define kColorTabBorder   [UIColor colorWithRed:0.80f green:0.80f blue:0.85f alpha:1.0f]
#define kColorText        [UIColor colorWithRed:0.10f green:0.10f blue:0.15f alpha:1.0f]
#define kColorMuted       [UIColor colorWithRed:0.50f green:0.50f blue:0.55f alpha:1.0f]
#define kColorSeparator   [UIColor colorWithRed:0.85f green:0.85f blue:0.88f alpha:1.0f]
#define kColorCheckOn     [UIColor colorWithRed:0.13f green:0.13f blue:0.18f alpha:1.0f]
#define kColorCheckBorder [UIColor colorWithRed:0.70f green:0.70f blue:0.75f alpha:1.0f]
#define kColorRowBG       [UIColor whiteColor]
#define kColorSectionText [UIColor colorWithRed:0.13f green:0.13f blue:0.18f alpha:1.0f]
#define kColorDangerBG    [UIColor colorWithRed:1.0f green:0.93f blue:0.93f alpha:1.0f]
#define kColorDanger      [UIColor colorWithRed:0.85f green:0.15f blue:0.15f alpha:1.0f]
#define kColorSliderFill  [UIColor colorWithRed:0.13f green:0.13f blue:0.18f alpha:1.0f]
#define kColorSliderTrack [UIColor colorWithRed:0.80f green:0.80f blue:0.85f alpha:1.0f]
#define kColorSegActive   [UIColor colorWithRed:0.13f green:0.13f blue:0.18f alpha:1.0f]
#define kColorSegBG       [UIColor colorWithRed:0.88f green:0.88f blue:0.91f alpha:1.0f]

static const NSInteger kSegmentTrackTag = 9101;
static const NSInteger kSegmentLabelTag = 9201;

typedef NS_ENUM(NSInteger, MenuTab) {
    MenuTabESP    = 0,
    MenuTabAimbot = 1,
    MenuTabMemory = 2,
    MenuTabInfo   = 3,
};

@interface ModMenuViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, assign) MenuTab              currentTab;
@property (nonatomic, strong) UIView               *floatingPanel;
@property (nonatomic, strong) UIScrollView         *contentScrollView;
@property (nonatomic, strong) UIView               *contentContainer;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;

@property (nonatomic, assign) NSInteger  trackingPointerId;
@property (nonatomic, assign) BOOL       touchOnClose;
@property (nonatomic, assign) BOOL       touchOnExitHUD;
@property (nonatomic, assign) BOOL       menuDragging;
@property (nonatomic, assign) CGPoint    menuDragStartOrigin;
@property (nonatomic, assign) CGPoint    menuDragStartTouch;

@property (nonatomic, weak)   UIView    *activeCheckbox;
@property (nonatomic, strong) UIView    *scrollbarTrack;
@property (nonatomic, strong) UIView    *scrollbarThumb;
@property (nonatomic, assign) BOOL       scrollbarDragging;
@property (nonatomic, weak)   UISlider  *sliderTracking;
@property (nonatomic, weak)   UIView    *segmentedRowTracking;
@property (nonatomic, assign) CGFloat    scrollbarDragStartY;
@property (nonatomic, assign) CGFloat    scrollbarDragStartOffsetY;

@property (nonatomic, assign) CGFloat        scrollVelocity;
@property (nonatomic, strong) CADisplayLink  *scrollDisplayLink;
@property (nonatomic, assign) CGFloat        scrollLastTouchY;
@property (nonatomic, assign) CFTimeInterval scrollLastTime;
@property (nonatomic, assign) BOOL           isScrollingContent;
@end

@implementation ModMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.multipleTouchEnabled = YES;
    _trackingPointerId = -1;
    _currentTab  = MenuTabESP;
    _tabButtons  = [NSMutableArray array];
    _isScrollingContent = NO;

    [self setupFloatingPanel];
    [self setupHeaderBar];
    [self setupTopTabBar];
    [self setupContentArea];
    [self loadTabContent:_currentTab];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(handleOutsideTap:)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
}

- (void)iPadLayoutCheck {}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (!_floatingPanel) return;
    CGRect s = self.view.bounds, f = _floatingPanel.frame;
    if (f.origin.x < 0) f.origin.x = 0;
    if (f.origin.y < 0) f.origin.y = 0;
    if (CGRectGetMaxX(f) > s.size.width)  f.origin.x = s.size.width  - f.size.width;
    if (CGRectGetMaxY(f) > s.size.height) f.origin.y = s.size.height - f.size.height;
    _floatingPanel.frame = f;
}

- (CGPoint)loadPanelPosition {
    CGFloat x = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingPanelX"];
    CGFloat y = [[NSUserDefaults standardUserDefaults] floatForKey:@"FloatingPanelY"];
    if (x <= 10.0f && y <= 10.0f) {
        CGRect s = [UIScreen mainScreen].bounds;
        x = MAX(0, (s.size.width - kPanelWidth) / 2.0f);
        y = 80.0f;
    }
    return CGPointMake(x, y);
}

- (void)setupFloatingPanel {
    CGPoint pos = [self loadPanelPosition];
    _floatingPanel = [[UIView alloc] initWithFrame:
        CGRectMake(pos.x, pos.y, kPanelWidth, kPanelHeight)];
    _floatingPanel.backgroundColor  = kColorBG;
    _floatingPanel.layer.cornerRadius = 12.0f;
    _floatingPanel.layer.shadowColor   = [UIColor blackColor].CGColor;
    _floatingPanel.layer.shadowOpacity = 0.25f;
    _floatingPanel.layer.shadowRadius  = 16.0f;
    _floatingPanel.layer.shadowOffset  = CGSizeMake(0, 4);
    _floatingPanel.layer.masksToBounds = NO;
    [self.view addSubview:_floatingPanel];

    UIView *clip = [[UIView alloc] initWithFrame:CGRectMake(0,0,kPanelWidth,kPanelHeight)];
    clip.backgroundColor = kColorBG;
    clip.layer.cornerRadius = 12.0f;
    clip.clipsToBounds = YES;
    clip.tag = 7777;
    [_floatingPanel addSubview:clip];
}

- (UIView *)clipContainer { return [_floatingPanel viewWithTag:7777]; }

// ─── Header ───────────────────────────────────
- (void)setupHeaderBar {
    UIView *clip = [self clipContainer];
    UIView *hdr  = [[UIView alloc] initWithFrame:CGRectMake(0,0,kPanelWidth,kHeaderHeight)];
    hdr.backgroundColor = kColorHeader;
    [clip addSubview:hdr];

    if (@available(iOS 13.0, *)) {
        UIImageView *gear = [[UIImageView alloc] initWithFrame:CGRectMake(12,10,20,20)];
        gear.image = [UIImage systemImageNamed:@"gearshape.fill"];
        gear.tintColor = [UIColor colorWithWhite:1.0f alpha:0.7f];
        gear.contentMode = UIViewContentModeScaleAspectFit;
        [hdr addSubview:gear];
    }

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(40,0,kPanelWidth-80,kHeaderHeight)];
    title.text = @"QHOANIOS - Free Fire";
    title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentLeft;
    [hdr addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(kPanelWidth-36, (kHeaderHeight-24)/2.0f, 24, 24);
    close.tag = 8001;
    if (@available(iOS 13.0, *)) {
        UIImage *x = [[UIImage systemImageNamed:@"xmark"]
            imageByApplyingSymbolConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold]];
        [close setImage:x forState:UIControlStateNormal];
    } else {
        [close setTitle:@"✕" forState:UIControlStateNormal];
    }
    close.tintColor = [UIColor colorWithWhite:1.0f alpha:0.7f];
    [hdr addSubview:close];

    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0,kHeaderHeight-1,kPanelWidth,1)];
    line.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.15f];
    [hdr addSubview:line];
}

// ─── Tab ngang ────────────────────────────────
- (void)setupTopTabBar {
    UIView *clip   = [self clipContainer];
    UIView *tabBar = [[UIView alloc] initWithFrame:
        CGRectMake(0, kHeaderHeight, kPanelWidth, kTopTabHeight)];
    tabBar.backgroundColor = kColorTabBar;
    tabBar.tag = 8888;
    [clip addSubview:tabBar];

    UIView *bot = [[UIView alloc] initWithFrame:CGRectMake(0,kTopTabHeight-1,kPanelWidth,1)];
    bot.backgroundColor = kColorTabBorder;
    [tabBar addSubview:bot];

    NSArray *titles = @[ @"ESP", @"AIMBOT", @"MEMORY", @"INFO" ];
    NSArray *icons  = @[ @"eye.fill", @"scope", @"memorychip", @"info.circle.fill" ];
    NSInteger n     = titles.count;
    CGFloat   tabW  = kPanelWidth / (CGFloat)n;

    for (NSInteger i = 0; i < n; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(tabW*i, 0, tabW, kTopTabHeight);
        btn.tag   = i;
        BOOL active = (i == _currentTab);
        btn.backgroundColor = active ? kColorTabActive : kColorTabInactive;

        if (@available(iOS 13.0, *)) {
            UIImage *ic = [[UIImage systemImageNamed:icons[i]]
                imageByApplyingSymbolConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium]];
            [btn setImage:ic forState:UIControlStateNormal];
            btn.tintColor = active ? kColorSectionText : kColorMuted;
            btn.imageEdgeInsets = UIEdgeInsetsMake(0,-4,0,4);
        }
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        [btn setTitleColor:(active ? kColorSectionText : kColorMuted) forState:UIControlStateNormal];

        if (i > 0) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0,8,1,kTopTabHeight-16)];
            sep.backgroundColor = kColorTabBorder;
            [btn addSubview:sep];
        }
        if (active) {
            UIView *ind = [[UIView alloc] initWithFrame:
                CGRectMake(tabW*0.15f, kTopTabHeight-2, tabW*0.70f, 2)];
            ind.backgroundColor = kColorSectionText;
            ind.layer.cornerRadius = 1.0f;
            ind.tag = 9999;
            [btn addSubview:ind];
        }
        [btn addTarget:self action:@selector(tabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [tabBar addSubview:btn];
        [_tabButtons addObject:btn];
    }
}

// ─── Content area ─────────────────────────────
- (void)setupContentArea {
    UIView  *clip     = [self clipContainer];
    CGFloat  topY     = kHeaderHeight + kTopTabHeight;
    CGFloat  contentH = kPanelHeight - topY;
    CGFloat  scrollW  = kPanelWidth - kScrollBarW - 4;

    UIView *contentClip = [[UIView alloc] initWithFrame:CGRectMake(0,topY,kPanelWidth,contentH)];
    contentClip.backgroundColor = kColorBG;
    contentClip.clipsToBounds   = YES;
    contentClip.tag = 4000;
    [clip addSubview:contentClip];

    _contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,0,scrollW,contentH)];
    _contentScrollView.backgroundColor = [UIColor clearColor];
    _contentScrollView.showsVerticalScrollIndicator = NO;
    _contentScrollView.bounces    = NO;
    _contentScrollView.scrollEnabled = NO;
    [contentClip addSubview:_contentScrollView];

    _contentContainer = [[UIView alloc] initWithFrame:CGRectMake(0,0,scrollW,contentH)];
    _contentContainer.backgroundColor = [UIColor clearColor];
    [_contentScrollView addSubview:_contentContainer];

    _scrollbarTrack = [[UIView alloc] initWithFrame:
        CGRectMake(kPanelWidth-kScrollBarW-2, 4, kScrollBarW, contentH-8)];
    _scrollbarTrack.backgroundColor = kColorSliderTrack;
    _scrollbarTrack.layer.cornerRadius = kScrollBarW/2.0f;
    [contentClip addSubview:_scrollbarTrack];

    _scrollbarThumb = [[UIView alloc] initWithFrame:
        CGRectMake(kPanelWidth-kScrollBarW-2, 4, kScrollBarW, 36.0f)];
    _scrollbarThumb.backgroundColor = kColorSliderFill;
    _scrollbarThumb.layer.cornerRadius = kScrollBarW/2.0f;
    [contentClip addSubview:_scrollbarThumb];
}

// ─── Tab visual update ────────────────────────
- (void)updateTabBarForTab:(MenuTab)tab {
    NSInteger n    = _tabButtons.count;
    CGFloat   tabW = kPanelWidth / (CGFloat)n;
    for (NSInteger i = 0; i < n; i++) {
        UIButton *btn  = _tabButtons[i];
        BOOL      active = (i == tab);
        btn.backgroundColor = active ? kColorTabActive : kColorTabInactive;
        [btn setTitleColor:(active ? kColorSectionText : kColorMuted) forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) btn.tintColor = active ? kColorSectionText : kColorMuted;
        [[btn viewWithTag:9999] removeFromSuperview];
        if (active) {
            UIView *ind = [[UIView alloc] initWithFrame:
                CGRectMake(tabW*0.15f, kTopTabHeight-2, tabW*0.70f, 2)];
            ind.backgroundColor = kColorSectionText;
            ind.layer.cornerRadius = 1.0f;
            ind.tag = 9999;
            [btn addSubview:ind];
        }
    }
}

// ─── Checkbox trái, label phải ────────────────
- (UIView *)makeCheckboxWithKey:(NSString *)key checked:(BOOL)checked x:(CGFloat)x y:(CGFloat)y {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(x,y,kCheckboxSize,kCheckboxSize)];
    box.backgroundColor    = checked ? kColorCheckOn : [UIColor whiteColor];
    box.layer.cornerRadius = 4.0f;
    box.layer.borderWidth  = 1.5f;
    box.layer.borderColor  = checked ? kColorCheckOn.CGColor : kColorCheckBorder.CGColor;
    box.tag = checked ? 1 : 0;
    objc_setAssociatedObject(box, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(box, "isCheckbox", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (checked) [self addCheckmarkTo:box];
    return box;
}

- (void)addCheckmarkTo:(UIView *)box {
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(3,3,kCheckboxSize-6,kCheckboxSize-6)];
    if (@available(iOS 13.0, *)) {
        iv.image = [[UIImage systemImageNamed:@"checkmark"]
            imageByApplyingSymbolConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold]];
    }
    iv.tintColor = [UIColor whiteColor];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tag = 9999;
    [box addSubview:iv];
}

- (void)setCheckbox:(UIView *)box checked:(BOOL)checked {
    box.tag = checked ? 1 : 0;
    box.backgroundColor = checked ? kColorCheckOn : [UIColor whiteColor];
    box.layer.borderColor = checked ? kColorCheckOn.CGColor : kColorCheckBorder.CGColor;
    [[box viewWithTag:9999] removeFromSuperview];
    if (checked) [self addCheckmarkTo:box];
}

- (UIView *)buildCheckboxCellWithTitle:(NSString *)title key:(NSString *)key frame:(CGRect)frame {
    BOOL on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    UIView *rv = [[UIView alloc] initWithFrame:frame];
    rv.backgroundColor = kColorRowBG;
    objc_setAssociatedObject(rv, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(12,frame.size.height-1,frame.size.width-12,1)];
    sep.backgroundColor = kColorSeparator;
    [rv addSubview:sep];

    // Checkbox bên TRÁI
    CGFloat cbY = (frame.size.height - kCheckboxSize) / 2.0f;
    UIView *cb  = [self makeCheckboxWithKey:key checked:on x:12 y:cbY];
    [rv addSubview:cb];

    // Label bên phải
    CGFloat lblX = 12 + kCheckboxSize + 10;
    UILabel *lbl = [[UILabel alloc] initWithFrame:
        CGRectMake(lblX, 0, frame.size.width-lblX-8, frame.size.height)];
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    lbl.textColor = kColorText;
    lbl.adjustsFontSizeToFitWidth = YES;
    lbl.minimumScaleFactor = 0.75f;
    [rv addSubview:lbl];
    return rv;
}

- (UILabel *)makeSectionLabel:(NSString *)text y:(CGFloat)y width:(CGFloat)w {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(12, y+8, w-24, 18)];
    l.text = text;
    l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    l.textColor = kColorSectionText;
    return l;
}

// ─── Tab content ──────────────────────────────
- (void)loadTabContent:(MenuTab)tab {
    for (UIView *v in _contentContainer.subviews) [v removeFromSuperview];
    _contentScrollView.contentOffset = CGPointZero;
    [self stopScrollInertia]; _scrollVelocity = 0;

    CGFloat w = _contentScrollView.bounds.size.width;
    _contentContainer.frame = CGRectMake(0,0,w,_contentScrollView.bounds.size.height);

    __block CGFloat y = 0;
    __weak typeof(self) ws = self;

    void (^sec)(NSString *) = ^(NSString *t) {
        UILabel *l = [ws makeSectionLabel:t y:y width:w];
        [ws->_contentContainer addSubview:l];
        y += 34;
    };
    void (^row)(NSString *, NSString *) = ^(NSString *t, NSString *k) {
        UIView *c = [ws buildCheckboxCellWithTitle:t key:k frame:CGRectMake(0,y,w,kRowHeight)];
        [ws->_contentContainer addSubview:c];
        y += kRowHeight;
    };

    // ── ESP ──────────────────────────────────
    if (tab == MenuTabESP) {
        sec(@"ESP");
        row(@"ESP ĐƯỜNG KẺ",    @"Line");
        row(@"ESP HỘP",         @"Box");
        row(@"ESP MÁU",         @"Health");
        row(@"ESP TÊN",         @"Name");
        row(@"ESP SỐ LƯỢNG",    @"Count");
        row(@"ESP XƯƠNG",       @"Bone");
        row(@"ESP KHOẢNG CÁCH", @"Dis");
        row(@"HIỆN FOV",        @"ShowFov");
        sec(@"KHÁC");
        row(@"Bot Thật",        (NSString *)NSSENCRYPT("EspBot"));

        y += 4;
        UIView *exitRow = [[UIView alloc] initWithFrame:CGRectMake(0,y,w,kRowHeight)];
        exitRow.backgroundColor = kColorDangerBG;
        objc_setAssociatedObject(exitRow, "key", @"__exit_hud__", OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UIView *exitSep = [[UIView alloc] initWithFrame:CGRectMake(12,kRowHeight-1,w-12,1)];
        exitSep.backgroundColor = kColorSeparator;
        [exitRow addSubview:exitSep];
        UILabel *exitLbl = [[UILabel alloc] initWithFrame:CGRectMake(12,0,w-24,kRowHeight)];
        exitLbl.text = @"Thoát HUD";
        exitLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        exitLbl.textColor = kColorDanger;
        [exitRow addSubview:exitLbl];
        [_contentContainer addSubview:exitRow];
        y += kRowHeight;
    }

    // ── AIMBOT ───────────────────────────────
    else if (tab == MenuTabAimbot) {
        sec(@"AIMBOT");
        row(@"Bật Aimbot",        @"Aimbot");
        row(@"Bỏ qua Bot",        @"AimIgnoreBot");
        row(@"Bỏ qua Gục",        @"AimIgnoreKnock");
        row(@"Chỉ khi thấy địch", @"AimCheckVisible");
        row(@"Rage Aimbot",       @"AimRage");
        row(@"Đường Aim",         @"LineAim");
        row(@"Nút Aim Nổi",       (NSString *)NSSENCRYPT("FloatAimBtn"));

        y += 6;
        CGFloat rw = w - 20;
        sec(@"CẤU HÌNH");
        y = [self addSegmentedRow:@"Chế độ kích hoạt" key:@"TriggerMode" y:y width:rw];
        y = [self addSegmentedRow:@"Vị trí khóa"      key:@"AimPos"       y:y width:rw];
        y += 6;
        sec(@"THÔNG SỐ");
        y = [self addSliderRow:@"FOV Aim" format:@"FOV Aim  —  %.0f px"
                           key:@"Fov" def:150 min:10 max:500 labelTag:6001 sliderTag:6002 y:y width:rw];
        y = [self addSliderRow:@"Khoảng cách" format:@"Khoảng cách  —  %.0f m"
                           key:@"Distance" def:200 min:1 max:400 labelTag:6003 sliderTag:6004 y:y width:rw];
        y = [self addSliderRow:@"Tốc độ khóa" format:@"Tốc độ  —  %.0f%%"
                           key:@"AimSpeed" def:100 min:1 max:100 labelTag:6005 sliderTag:6006 y:y width:rw];
    }

    // ── MEMORY ───────────────────────────────
    else if (tab == MenuTabMemory) {
        sec(@"MEMORY");
        row(@"Không cần reload", @"NoReLoad");
        row(@"Vô hạn đạn",       @"VohaDan");
        row(@"Bắn nhanh",        @"FastFire");
        row(@"Cam cao",          @"camcao");

        y += 6;
        CGFloat rw = w - 20;
        sec(@"CAM CAO");
        y = [self addSliderRow:@"Tỷ lệ cam cao" format:@"Cam Cao  —  %.0f"
                           key:@"Campc" def:1 min:1 max:100 labelTag:7001 sliderTag:7002 y:y width:rw];
    }

    // ── INFO ─────────────────────────────────
    else {
        sec(@"THÔNG TIN");
        CGFloat ix = 12;
        auto infoRow = ^(NSString *label, NSString *value) {
            UIView *rv = [[UIView alloc] initWithFrame:CGRectMake(0,y,w,36)];
            rv.backgroundColor = kColorRowBG;
            UIView *sp = [[UIView alloc] initWithFrame:CGRectMake(12,35,w-12,1)];
            sp.backgroundColor = kColorSeparator; [rv addSubview:sp];
            UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(ix,0,w*0.45f,36)];
            l.text = label; l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
            l.textColor = kColorMuted; [rv addSubview:l];
            UILabel *v = [[UILabel alloc] initWithFrame:CGRectMake(ix+w*0.45f,0,w*0.50f,36)];
            v.text = value; v.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
            v.textColor = kColorText; v.textAlignment = NSTextAlignmentRight;
            v.adjustsFontSizeToFitWidth = YES; v.minimumScaleFactor = 0.7f;
            [rv addSubview:v];
            [_contentContainer addSubview:rv];
            y += 36;
        };
        infoRow(@"Dev",       @"@qhoanioss");
        infoRow(@"Telegram",  @"@qhoanioss");
        infoRow(@"Game",      @"Free Fire");
        infoRow(@"Phiên bản", @"1.20.1");
    }

    [self finalizeContentHeight:y contentWidth:w];
}

- (void)finalizeContentHeight:(CGFloat)y contentWidth:(CGFloat)cw {
    _contentContainer.frame = CGRectMake(0,0,cw,y+8);
    _contentScrollView.contentSize = _contentContainer.frame.size;
    [self updateScrollbarLayout];
}

// ─── Scrollbar ────────────────────────────────
- (void)updateScrollbarLayout {
    CGFloat ch = _contentScrollView.contentSize.height;
    CGFloat vh = _contentScrollView.bounds.size.height;
    if (ch <= vh || vh <= 0) { _scrollbarTrack.hidden = _scrollbarThumb.hidden = YES; return; }
    _scrollbarTrack.hidden = _scrollbarThumb.hidden = NO;
    CGFloat maxOff = ch - vh;
    CGFloat thH    = vh * (vh / ch);
    if (thH < 28) thH = 28;
    if (thH > vh-4) thH = vh-4;
    CGFloat range = vh - thH;
    CGFloat thY   = range > 0 ? (_contentScrollView.contentOffset.y / maxOff) * range : 0;
    thY = MAX(0, MIN(range, thY));
    _scrollbarThumb.frame = CGRectMake(_scrollbarThumb.frame.origin.x, thY+4, kScrollBarW, thH);
}

- (void)startScrollInertia {
    [self stopScrollInertia];
    if (ABS(_scrollVelocity) < 1.0f) return;
    _scrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(scrollInertiaStep)];
    [_scrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}
- (void)stopScrollInertia { [_scrollDisplayLink invalidate]; _scrollDisplayLink = nil; }
- (void)scrollInertiaStep {
    _scrollVelocity *= 0.92f;
    if (ABS(_scrollVelocity) < 0.5f) { [self stopScrollInertia]; return; }
    [self applyScrollDelta:_scrollVelocity];
}
- (void)applyScrollDelta:(CGFloat)d {
    CGFloat ch = _contentScrollView.contentSize.height;
    CGFloat vh = _contentScrollView.bounds.size.height;
    CGFloat no = MAX(0, MIN(ch-vh, _contentScrollView.contentOffset.y + d));
    _contentScrollView.contentOffset = CGPointMake(0, no);
    [self updateScrollbarLayout];
}

// ─── Slider ───────────────────────────────────
- (CGFloat)addSliderRow:(NSString *)name format:(NSString *)fmt key:(NSString *)key
                    def:(CGFloat)def min:(float)mn max:(float)mx
               labelTag:(NSInteger)lt sliderTag:(NSInteger)st y:(CGFloat)y width:(CGFloat)rw {
    CGFloat val = ESPPrefsFloat(key, def);
    if (val < mn || val > mx) val = def;
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10,y,rw,16)];
    lbl.text = [NSString stringWithFormat:fmt, val];
    lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    lbl.textColor = kColorText; lbl.tag = lt;
    [_contentContainer addSubview:lbl]; y += 18;
    UISlider *sl = [[UISlider alloc] initWithFrame:CGRectMake(10,y,rw,24)];
    sl.minimumValue = mn; sl.maximumValue = mx; sl.value = (float)val;
    sl.minimumTrackTintColor = kColorSliderFill;
    sl.maximumTrackTintColor = kColorSliderTrack;
    sl.thumbTintColor = kColorSliderFill;
    sl.tag = st;
    objc_setAssociatedObject(sl, "key", key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(sl, "label", lbl, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(sl, "fmt", fmt, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sl addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_contentContainer addSubview:sl]; y += 28;
    return y;
}

// ─── Segmented ────────────────────────────────
- (NSArray<NSString *> *)comboOptionsForKey:(NSString *)key {
    if ([key isEqualToString:@"TriggerMode"]) return @[ @"Auto", @"Bắn", @"Ngắm", @"Combo" ];
    if ([key isEqualToString:@"AimPos"])      return @[ @"Đầu", @"Cổ", @"Ngực" ];
    return @[];
}

- (void)updateSegmentedRowVisual:(UIView *)row selectedIndex:(int)sel {
    NSArray *cells = objc_getAssociatedObject(row, "segCells");
    for (NSInteger i = 0; i < (NSInteger)cells.count; i++) {
        UIView *cell = cells[i]; UILabel *lab = [cell viewWithTag:kSegmentLabelTag];
        BOOL a = (i == sel);
        cell.backgroundColor = a ? kColorSegActive : [UIColor clearColor];
        if (lab) { lab.textColor = a ? [UIColor whiteColor] : kColorMuted;
                   lab.font = [UIFont systemFontOfSize:11 weight:a ? UIFontWeightBold : UIFontWeightMedium]; }
    }
}

- (CGFloat)addSegmentedRow:(NSString *)title key:(NSString *)key y:(CGFloat)y width:(CGFloat)rw {
    NSArray *opts = [self comboOptionsForKey:key];
    if (!opts.count) return y;
    const CGFloat tH=16,pH=26,vG=4,bP=5;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(10,y,rw,tH+vG+pH+bP)];
    row.backgroundColor = [UIColor clearColor];
    objc_setAssociatedObject(row, "segComboPrefsKey", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(0,0,rw,tH)];
    tl.text = title; tl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    tl.textColor = kColorMuted; [row addSubview:tl];
    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(0,tH+vG,rw,pH)];
    track.tag = kSegmentTrackTag; track.backgroundColor = kColorSegBG;
    track.layer.cornerRadius = 6; track.layer.borderWidth = 1;
    track.layer.borderColor = kColorTabBorder.CGColor; track.clipsToBounds = YES;
    [row addSubview:track];
    int sel = (int)ESPPrefsFloat(key, 0);
    if (sel<0||sel>=(int)opts.count) sel=0;
    CGFloat sw = rw/(CGFloat)opts.count;
    NSMutableArray *cells = [NSMutableArray array];
    for (NSInteger i=0;i<(NSInteger)opts.count;i++) {
        UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(sw*i+2,2,sw-4,pH-4)];
        cell.layer.cornerRadius = 4; cell.userInteractionEnabled = NO;
        UILabel *lab = [[UILabel alloc] initWithFrame:cell.bounds];
        lab.tag = kSegmentLabelTag; lab.text = opts[i];
        lab.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        lab.textAlignment = NSTextAlignmentCenter; lab.textColor = kColorMuted;
        lab.adjustsFontSizeToFitWidth = YES; lab.minimumScaleFactor = 0.65;
        [cell addSubview:lab]; [track addSubview:cell]; [cells addObject:cell];
    }
    objc_setAssociatedObject(row, "segCells", cells, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self updateSegmentedRowVisual:row selectedIndex:sel];
    [_contentContainer addSubview:row];
    return y + tH+vG+pH+bP + 4;
}

- (void)applySegmentedSelectionForRow:(UIView *)row touchInContent:(CGPoint)pt {
    NSString *key = objc_getAssociatedObject(row, "segComboPrefsKey");
    NSArray *cells = objc_getAssociatedObject(row, "segCells");
    UIView *track  = [row viewWithTag:kSegmentTrackTag];
    if (!key||!track||!cells.count) return;
    CGPoint ir = CGPointMake(pt.x-row.frame.origin.x, pt.y-row.frame.origin.y);
    if (!CGRectContainsPoint(track.frame, ir)) return;
    CGFloat rx = ir.x - track.frame.origin.x;
    NSInteger n = (NSInteger)cells.count;
    NSInteger idx = (NSInteger)(rx / (track.bounds.size.width / (CGFloat)n));
    idx = MAX(0, MIN(n-1, idx));
    ESPPrefsSetFloat(key, (float)idx); ESPSyncFromPrefs();
    [self updateSegmentedRowVisual:row selectedIndex:(int)idx];
    [self notifyMenuView];
}

// ─── Actions ──────────────────────────────────
- (void)tabButtonTapped:(UIButton *)sender {
    MenuTab t = (MenuTab)sender.tag;
    if (t == _currentTab) return;
    _currentTab = t;
    [self updateTabBarForTab:t];
    [self loadTabContent:t];
}

- (void)checkboxTappedWithView:(UIView *)box {
    NSString *key = objc_getAssociatedObject(box, "key");
    if (!key) return;
    BOOL nv = (box.tag == 0);
    [self setCheckbox:box checked:nv];
    ESPPrefsSetBool(key, nv);
    [[NSUserDefaults standardUserDefaults] setBool:nv forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    ESPSyncFromPrefs();
    [self notifyMenuView];
}

- (void)notifyMenuView {
    for (UIView *v = self.view.superview; v; v = v.superview) {
        if ([v isKindOfClass:[MenuView class]]) {
            [(MenuView *)v reloadFloatingAuxButtonsFromPrefs]; break;
        }
    }
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    if (!key) return;
    float val = sender.value;
    ESPPrefsSetFloat(key, val);
    [[NSUserDefaults standardUserDefaults] setFloat:val forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    ESPSyncFromPrefs();
    UILabel *l = objc_getAssociatedObject(sender, "label");
    NSString *f = objc_getAssociatedObject(sender, "fmt");
    if (l&&f) l.text = [NSString stringWithFormat:f, val];
}

- (void)closeTapped {
    [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.x forKey:@"FloatingPanelX"];
    [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.y forKey:@"FloatingPanelY"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (self.onCloseBlock) self.onCloseBlock();
}

- (void)handleOutsideTap:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self.view];
    if (!CGRectContainsPoint(_floatingPanel.frame, p)) [self closeTapped];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    return !CGRectContainsPoint(_floatingPanel.frame, [touch locationInView:self.view]);
}

// ─── Touch ────────────────────────────────────
- (BOOL)handleTouchAtViewPoint:(CGPoint)point phase:(NSInteger)phase pointerId:(NSInteger)pointerId {
    BOOL inside = CGRectContainsPoint(_floatingPanel.frame, point);
    UITouchPhase ph = (UITouchPhase)phase;

    if (ph == UITouchPhaseBegan) {
        if (!inside) return NO;
        if (_trackingPointerId != -1 && _trackingPointerId != pointerId) return NO;
        _trackingPointerId = pointerId;
        _touchOnClose = _touchOnExitHUD = _menuDragging = NO;
        _activeCheckbox = nil; _segmentedRowTracking = nil; _sliderTracking = nil;
        _isScrollingContent = NO;
        [self stopScrollInertia]; _scrollVelocity = 0;

        CGPoint ip = CGPointMake(point.x-_floatingPanel.frame.origin.x,
                                 point.y-_floatingPanel.frame.origin.y);

        // Header
        if (ip.y < kHeaderHeight) {
            CGRect cr = CGRectMake(kPanelWidth-36,(kHeaderHeight-24)/2.0f,24,24);
            if (CGRectContainsPoint(CGRectInset(cr,-8,-8), ip)) { _touchOnClose = YES; }
            else { _menuDragging=YES; _menuDragStartOrigin=_floatingPanel.frame.origin; _menuDragStartTouch=point; }
            return YES;
        }
        // Tab bar ngang
        if (ip.y < kHeaderHeight+kTopTabHeight) {
            NSInteger n = _tabButtons.count;
            CGFloat tw  = kPanelWidth/(CGFloat)n;
            NSInteger idx = MAX(0,MIN(n-1,(NSInteger)(ip.x/tw)));
            if (idx != (NSInteger)_currentTab) [self tabButtonTapped:_tabButtons[idx]];
            return YES;
        }
        // Scrollbar
        if (ip.x >= (kPanelWidth-kScrollBarW-4)) {
            CGFloat trackY = ip.y - kHeaderHeight - kTopTabHeight;
            CGFloat vh = _contentScrollView.bounds.size.height;
            CGFloat ch = _contentScrollView.contentSize.height;
            CGFloat maxOff = ch-vh;
            if (maxOff > 0) {
                CGFloat tY = _scrollbarThumb.frame.origin.y;
                CGFloat tH = _scrollbarThumb.frame.size.height;
                if (trackY>=tY && trackY<=tY+tH) {
                    _scrollbarDragging=YES;
                    _scrollbarDragStartY=point.y;
                    _scrollbarDragStartOffsetY=_contentScrollView.contentOffset.y;
                } else {
                    CGFloat th = _scrollbarTrack.frame.size.height;
                    CGFloat range = th-tH;
                    if (range>0) {
                        CGFloat no = (trackY/th)*maxOff;
                        _contentScrollView.contentOffset = CGPointMake(0,MAX(0,MIN(maxOff,no)));
                        [self updateScrollbarLayout];
                    }
                }
            }
            return YES;
        }

        _scrollLastTouchY = point.y; _scrollLastTime = CACurrentMediaTime();
        CGPoint ic = CGPointMake(ip.x, ip.y-kHeaderHeight-kTopTabHeight+_contentScrollView.contentOffset.y);

        for (UIView *rv in _contentContainer.subviews) {
            if ([rv isKindOfClass:[UISlider class]]||[rv isKindOfClass:[UILabel class]]) continue;
            if (!CGRectContainsPoint(rv.frame, ic)) continue;
            NSString *sk = objc_getAssociatedObject(rv,"segComboPrefsKey");
            if (sk) {
                UIView *tr = [rv viewWithTag:kSegmentTrackTag];
                CGPoint ir = CGPointMake(ic.x-rv.frame.origin.x, ic.y-rv.frame.origin.y);
                if (tr&&CGRectContainsPoint(tr.frame,ir)) _segmentedRowTracking=rv;
                break;
            }
            NSString *rk = objc_getAssociatedObject(rv,"key");
            if ([rk isEqualToString:@"__exit_hud__"]) { _touchOnExitHUD=YES; break; }
            for (UIView *sub in rv.subviews)
                if (objc_getAssociatedObject(sub,"isCheckbox")) { _activeCheckbox=sub; break; }
            break;
        }
        if (!_activeCheckbox&&!_touchOnExitHUD&&!_segmentedRowTracking)
            for (UIView *v in _contentContainer.subviews)
                if ([v isKindOfClass:[UISlider class]]&&CGRectContainsPoint(v.frame,ic))
                    { _sliderTracking=(UISlider*)v; break; }
        return YES;
    }

    if (ph == UITouchPhaseMoved) {
        if (pointerId != _trackingPointerId) return NO;
        if (_sliderTracking) {
            CGPoint ip = CGPointMake(point.x-_floatingPanel.frame.origin.x,
                                     point.y-_floatingPanel.frame.origin.y);
            CGPoint ic = CGPointMake(ip.x, ip.y-kHeaderHeight-kTopTabHeight+_contentScrollView.contentOffset.y);
            UISlider *sl = _sliderTracking;
            CGFloat r = (ic.x-sl.frame.origin.x)/sl.frame.size.width;
            sl.value = sl.minimumValue + (float)MAX(0,MIN(1,r))*(sl.maximumValue-sl.minimumValue);
            [self sliderChanged:sl]; return YES;
        }
        if (_scrollbarDragging) {
            CGFloat ch=_contentScrollView.contentSize.height,vh=_contentScrollView.bounds.size.height;
            CGFloat maxOff=ch-vh;
            if (maxOff<=0) { _scrollbarDragging=NO; return YES; }
            CGFloat no = _scrollbarDragStartOffsetY+(point.y-_scrollbarDragStartY);
            _contentScrollView.contentOffset = CGPointMake(0,MAX(0,MIN(maxOff,no)));
            [self updateScrollbarLayout]; return YES;
        }
        if (_menuDragging) {
            CGFloat dx=point.x-_menuDragStartTouch.x, dy=point.y-_menuDragStartTouch.y;
            CGRect s=self.view.bounds;
            CGFloat nx=MAX(0,MIN(s.size.width-kPanelWidth,_menuDragStartOrigin.x+dx));
            CGFloat ny=MAX(0,MIN(s.size.height-kPanelHeight,_menuDragStartOrigin.y+dy));
            _floatingPanel.frame = CGRectMake(nx,ny,kPanelWidth,kPanelHeight); return YES;
        }
        CGFloat ipy = point.y-_floatingPanel.frame.origin.y;
        if (ipy > kHeaderHeight+kTopTabHeight) {
            CFTimeInterval now = CACurrentMediaTime();
            CGFloat dy = point.y-_scrollLastTouchY;
            if (now-_scrollLastTime>0.001) _scrollVelocity=-dy/(CGFloat)((now-_scrollLastTime)*60.0);
            [self applyScrollDelta:-dy];
            if (ABS(dy)>3) { _isScrollingContent=YES; _activeCheckbox=nil; _segmentedRowTracking=nil; _touchOnExitHUD=NO; }
            _scrollLastTouchY=point.y; _scrollLastTime=now; return YES;
        }
    }

    if (ph==UITouchPhaseEnded||ph==UITouchPhaseCancelled) {
        if (pointerId != _trackingPointerId) return NO;
        if (_touchOnClose) { [self closeTapped]; }
        else if (_touchOnExitHUD&&!_isScrollingContent&&self.onExitHUDRequested) { self.onExitHUDRequested(); }
        else if (_activeCheckbox&&!_isScrollingContent) { [self checkboxTappedWithView:_activeCheckbox]; }
        else if (_segmentedRowTracking&&!_isScrollingContent) {
            CGPoint ip = CGPointMake(point.x-_floatingPanel.frame.origin.x,
                                     point.y-_floatingPanel.frame.origin.y);
            CGPoint ic = CGPointMake(ip.x, ip.y-kHeaderHeight-kTopTabHeight+_contentScrollView.contentOffset.y);
            [self applySegmentedSelectionForRow:_segmentedRowTracking touchInContent:ic];
        } else if (_menuDragging) {
            [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.x forKey:@"FloatingPanelX"];
            [[NSUserDefaults standardUserDefaults] setFloat:_floatingPanel.frame.origin.y forKey:@"FloatingPanelY"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else if (_scrollbarDragging) { [self updateScrollbarLayout]; }
        else if (_isScrollingContent) { [self startScrollInertia]; }
        _trackingPointerId=-1;
        _touchOnClose=_touchOnExitHUD=_menuDragging=_scrollbarDragging=NO;
        _activeCheckbox=nil; _segmentedRowTracking=nil; _sliderTracking=nil;
        _isScrollingContent=NO; return YES;
    }
    return (inside&&pointerId==_trackingPointerId)||_scrollbarDragging;
}

@end
