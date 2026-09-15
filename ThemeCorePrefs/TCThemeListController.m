#import "TCThemeListController.h"
#import "TCThemeItem.h"
#import <objc/runtime.h>
#import <notify.h>

// theos 精简版 Preferences 头未声明 -setSpecifiers:animated:（运行时存在），补声明
@interface PSListController (TCCompat)
- (void)setSpecifiers:(NSArray *)specifiers animated:(BOOL)animated;
@end

#pragma mark - rootless 路径换算（与 postinst 探测逻辑一致）

static NSString *TCRootPath(NSString *path) {
    // 只有越狱根目录下的 /Library 路径需要映射；用户偏好位于真实的 /var/mobile。
    if (![path hasPrefix:@"/Library/"]) return path;
    NSString *prefix = @"";
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
        prefix = @"/var/jb";
    } else {
        NSArray *candidates = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:@"/var/containers/Bundle/Application" error:nil];
        for (NSString *c in candidates) {
            if ([c hasPrefix:@".jbroot-"]) {
                prefix = [@"/var/containers/Bundle/Application" stringByAppendingPathComponent:c];
                break;
            }
        }
    }
    return prefix.length ? [prefix stringByAppendingString:path] : path;
}

static NSString *const TCPreferencesPath = @"/var/mobile/Library/Preferences/com.susudear.themecore.plist";
static NSString *const TCThemesDirectory = @"/Library/Themes";
static NSString *const TCEnabledKey       = @"Enabled";
static NSString *const TCActiveThemeKey   = @"ActiveTheme";
static NSString *const TCEnabledThemesKey = @"EnabledThemes";
static NSString *const TCReloadDarwinName = @"com.susudear.themecore.reload";

@interface TCThemeListController ()
@property (nonatomic, copy) NSArray<TCThemeGroup *> *groups;
@property (nonatomic, strong) NSMutableArray<TCThemeItem *> *flatItems;
@property (nonatomic, assign) BOOL grouped;
@end

@implementation TCThemeListController

- (instancetype)init {
    self = [super init];
    if (self) {
        _grouped = NO;
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"ThemeList" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NSLocalizedStringFromTableInBundle(@"SELECT_THEME", @"ThemeList",
                                                    [NSBundle bundleForClass:self.class], nil);

    UIBarButtonItem *groupButton = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedStringFromTableInBundle(@"GROUP", @"ThemeList",
                                                          [NSBundle bundleForClass:self.class], nil)
                style:UIBarButtonItemStylePlain
               target:self action:@selector(toggleGrouping)];
    self.navigationItem.rightBarButtonItem = groupButton;

    [self reloadThemes];
}

#pragma mark - 数据

- (void)reloadThemes {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:TCPreferencesPath];
    NSString *active = prefs[TCActiveThemeKey];
    NSArray *enabledThemes = [prefs[TCEnabledThemesKey] isKindOfClass:NSArray.class]
        ? prefs[TCEnabledThemesKey] : @[];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = TCRootPath(TCThemesDirectory);
    NSMutableArray<TCThemeItem *> *items = [NSMutableArray array];

    for (NSString *entry in [fm contentsOfDirectoryAtPath:dir error:nil]) {
        if (![entry.pathExtension isEqualToString:@"theme"]) continue;
        NSString *path = [dir stringByAppendingPathComponent:entry];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) continue;

        TCThemeItem *item = [TCThemeItem new];
        item.name = [entry stringByDeletingPathExtension];
        item.packageName = [NSDictionary dictionaryWithContentsOfFile:
                            [path stringByAppendingPathComponent:@"Info.plist"]][@"PackageName"];
        item.enabled = [enabledThemes containsObject:item.name];
        item.isActive = [active isEqualToString:item.name];

        // 图标统计
        NSUInteger icons = 0, exts = 0;
        NSArray *iconFiles = [fm contentsOfDirectoryAtPath:[path stringByAppendingPathComponent:@"IconBundles"]
                                                     error:nil];
        for (NSString *f in iconFiles) {
            if ([f.pathExtension isEqualToString:@"png"]) {
                icons++;
                if ([f containsString:@"-large"]) exts++;
            }
        }
        item.iconCount = icons;
        item.extensionCount = exts;

        // 预览图
        NSString *preview = [path stringByAppendingPathComponent:@"ThemeIcon.png"];
        if (![fm fileExistsAtPath:preview]) {
            preview = [path stringByAppendingPathComponent:@"IconBundles/com.apple.mobilemail.png"];
        }
        item.previewImage = [UIImage imageWithContentsOfFile:preview];

        [items addObject:item];
    }

    [items sortUsingComparator:^NSComparisonResult(TCThemeItem *a, TCThemeItem *b) {
        return [a.name localizedStandardCompare:b.name];
    }];

    self.flatItems = items;
    [self _rebuildGroups];
    [self reloadSpecifiers];
}

- (void)_rebuildGroups {
    NSMutableArray<TCThemeGroup *> *groups = [NSMutableArray array];
    if (self.grouped) {
        // 按包名首字母/前缀分组（简化：按 packageName 分组）
        NSMutableDictionary<NSString *, NSMutableArray<TCThemeItem *> *> *map = [NSMutableDictionary dictionary];
        for (TCThemeItem *item in self.flatItems) {
            NSString *key = item.packageName.length ? item.packageName : NSLocalizedStringFromTableInBundle(
                @"UNGROUP", @"ThemeList", [NSBundle bundleForClass:self.class], nil);
            if (!map[key]) map[key] = [NSMutableArray array];
            [map[key] addObject:item];
        }
        for (NSString *key in map) {
            TCThemeGroup *g = [TCThemeGroup new];
            g.title = key;
            g.items = [map[key] sortedArrayUsingComparator:^NSComparisonResult(TCThemeItem *a, TCThemeItem *b) {
                return [a.name localizedStandardCompare:b.name];
            }];
            [groups addObject:g];
        }
        [groups sortUsingComparator:^NSComparisonResult(TCThemeGroup *a, TCThemeGroup *b) {
            return [a.title localizedStandardCompare:b.title];
        }];
    } else {
        TCThemeGroup *g = [TCThemeGroup new];
        g.title = NSLocalizedStringFromTableInBundle(@"UNGROUP", @"ThemeList",
                                                      [NSBundle bundleForClass:self.class], nil);
        g.items = self.flatItems;
        [groups addObject:g];
    }
    self.groups = groups;
}

- (void)reloadSpecifiers {
    NSMutableArray *specs = [NSMutableArray array];

    if (self.flatItems.count == 0) {
        PSSpecifier *empty = [PSSpecifier emptyGroupSpecifier];
        [specs addObject:empty];
        PSSpecifier *noTheme = [PSSpecifier preferenceSpecifierNamed:
            NSLocalizedStringFromTableInBundle(@"NO_THEMES", @"ThemeList",
                                                [NSBundle bundleForClass:self.class], nil)
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                              detail:Nil
                                                                cell:PSTitleValueCell
                                                                edit:Nil];
        [specs addObject:noTheme];
    } else {
        for (TCThemeGroup *group in self.groups) {
            PSSpecifier *header = [PSSpecifier groupSpecifierWithName:group.title];
            [specs addObject:header];
            for (TCThemeItem *item in group.items) {
                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:item.name
                                                                   target:self
                                                                      set:@selector(setTheme:specifier:)
                                                                      get:@selector(getTheme:)
                                                                  detail:Nil
                                                                    cell:PSSwitchCell
                                                                    edit:Nil];
                spec.identifier = item.name;
                [spec setProperty:item forKey:@"tc_item"];
                [specs addObject:spec];
            }
        }
    }
    [self setSpecifiers:specs animated:NO];
}

#pragma mark - 读写偏好

- (id)getTheme:(PSSpecifier *)specifier {
    TCThemeItem *item = [specifier propertyForKey:@"tc_item"];
    return @(item.enabled);
}

- (void)setTheme:(NSNumber *)value specifier:(PSSpecifier *)specifier {
    TCThemeItem *item = [specifier propertyForKey:@"tc_item"];
    item.enabled = value.boolValue;

    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:TCPreferencesPath]
        ?: [NSMutableDictionary dictionary];
    NSMutableArray *enabled = [prefs[TCEnabledThemesKey] mutableCopy] ?: [NSMutableArray array];

    if (value.boolValue) {
        if (![enabled containsObject:item.name]) [enabled addObject:item.name];
        prefs[TCActiveThemeKey] = item.name;   // 启用即激活
    } else {
        [enabled removeObject:item.name];
        if ([prefs[TCActiveThemeKey] isEqualToString:item.name]) {
            prefs[TCActiveThemeKey] = enabled.lastObject;
        }
    }
    prefs[TCEnabledThemesKey] = enabled;
    prefs[TCEnabledKey] = @YES;

    if (![prefs writeToFile:TCPreferencesPath atomically:YES]) {
        NSLog(@"[ThemeCorePrefs] failed to write configuration");
    }

    // 通知 Tweak 重载
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)TCReloadDarwinName, NULL, nil, YES);
    notify_post("com.susudear.themecore/reload");

    [self reloadThemes];
}

- (void)toggleGrouping {
    self.grouped = !self.grouped;
    self.navigationItem.rightBarButtonItem.title = NSLocalizedStringFromTableInBundle(
        self.grouped ? @"UNGROUP" : @"GROUP", @"ThemeList",
        [NSBundle bundleForClass:self.class], nil);
    [self _rebuildGroups];
    [self reloadSpecifiers];
}

@end
