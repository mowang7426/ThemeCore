#import "TCThemeStore.h"
#import <libkern/OSAtomic.h>
#import <sys/stat.h>

#pragma mark - rootless 路径换算（与 postinst 探测逻辑一致）

static NSString *TCRootPrefix(void) {
    static NSString *prefix;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
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
        if (!prefix) prefix = @"";
    });
    return prefix;
}

static NSString *TCRootPath(NSString *path) {
    NSString *p = TCRootPrefix();
    return p.length ? [p stringByAppendingString:path] : path;
}

/// 偏好与目录常量
static NSString *const TCPreferencesPath     = @"/var/mobile/Library/Preferences/com.susudear.themecore.plist";
static NSString *const TCThemesDirectoryName = @"/Library/Themes";      // 用户放主题的目录
static NSString *const TCStoreDirectoryName  = @"/Library/ThemeCore";   // 编译产物目录
static NSString *const TCReloadDarwinName    = @"com.susudear.themecore.reload";

static NSString *const TCEnabledKey        = @"Enabled";
static NSString *const TCActiveThemeKey    = @"ActiveTheme";
static NSString *const TCEnabledThemesKey  = @"EnabledThemes";

@interface TCThemeStore ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mIconPaths;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mClockPaths;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *mShadowPaths;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *mThemeInfo;
@property (nonatomic, strong) NSMutableArray<TCTheme *> *mThemes;
@property (nonatomic, strong) dispatch_source_t memoryPressureSource;
@property (nonatomic, assign) NSUInteger generation;   // 每次 reload 自增，用于缓存键失效
@end

@implementation TCTheme

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _path = [path copy];
        _name = [[path lastPathComponent] stringByDeletingPathExtension];
        [self _scanMetadata];
    }
    return self;
}

- (void)_scanMetadata {
    NSString *infoPath = [self.path stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    self.packageName = info[@"PackageName"];
    self.modern = [info[@"modern"] boolValue];

    // 图标资源：IconBundles/*.png 与 Bundles/*/ 两种布局
    NSString *iconBundles = [self.path stringByAppendingPathComponent:@"IconBundles"];
    NSString *bundles     = [self.path stringByAppendingPathComponent:@"Bundles"];

    NSUInteger icons = 0, extensions = 0;
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray<NSString *> *iconFiles = [fm contentsOfDirectoryAtPath:iconBundles error:nil];
    for (NSString *file in iconFiles) {
        if ([file.pathExtension isEqualToString:@"png"]) {
            icons++;
            if ([file containsString:@"-large"]) extensions++;
        }
    }
    NSArray<NSString *> *bundleDirs = [fm contentsOfDirectoryAtPath:bundles error:nil];
    for (NSString *dir in bundleDirs) {
        NSString *dirPath = [bundles stringByAppendingPathComponent:dir];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:dirPath isDirectory:&isDir] && isDir) {
            NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:dirPath error:nil];
            for (NSString *file in files) {
                if ([file.pathExtension isEqualToString:@"png"]) icons++;
            }
        }
    }

    // Effects/AnemoneEffects、Effects/Iconomatic：叠加特效
    NSArray<NSString *> *effectRoots = @[
        @"Effects/AnemoneEffects",
        @"Effects/Iconomatic"
    ];
    for (NSString *rel in effectRoots) {
        NSString *dir = [self.path stringByAppendingPathComponent:rel];
        extensions += [[fm contentsOfDirectoryAtPath:dir error:nil] count];
    }

    // 时钟资源
    NSArray<NSString *> *clockKeys = @[
        @"clock.background", @"ClockIconBackgroundSquare",
        @"ClockIconSecondHand", @"ClockIconMinuteHand", @"ClockIconHourHand",
        @"ClockIconRedDot", @"ClockIconBlackDot"
    ];
    for (NSString *key in clockKeys) {
        if ([self _findClockFileForKey:key]) { self.hasClock = YES; break; }
    }

    // 阴影资源
    NSString *shadowDir = [self.path stringByAppendingPathComponent:@"Effects/Shadow"];
    self.hasShadow = [[fm contentsOfDirectoryAtPath:shadowDir error:nil] count] > 0;

    self.iconCount = icons;
    self.extensionCount = extensions;
}

/// 在 IconBundles 与 Bundles/com.apple.mobiletimer 下查找时钟素材
- (nullable NSString *)_findClockFileForKey:(NSString *)key {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *candidates = @[
        [self.path stringByAppendingPathComponent:[NSString stringWithFormat:@"IconBundles/%@.png", key]],
        [self.path stringByAppendingPathComponent:[NSString stringWithFormat:@"Bundles/com.apple.mobiletimer/%@.png", key]],
        [self.path stringByAppendingPathComponent:[NSString stringWithFormat:@"Bundles/com.apple.mobiletimer/%@.png", [key stringByAppendingString:@"-large"]]],
    ];
    for (NSString *c in candidates) {
        if ([fm fileExistsAtPath:c]) return c;
    }
    return nil;
}

@end

@implementation TCThemeStore

+ (TCThemeStore *)sharedStore {
    static TCThemeStore *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[TCThemeStore alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _imageCache = [[NSCache alloc] init];
        _imageCache.countLimit = 512;
        _imageCache.totalCostLimit = 128 * 1024 * 1024;
        _mIconPaths = [NSMutableDictionary dictionary];
        _mClockPaths = [NSMutableDictionary dictionary];
        _mShadowPaths = [NSMutableDictionary dictionary];
        _mThemeInfo = [NSMutableDictionary dictionary];
        _mThemes = [NSMutableArray array];

        // 读取偏好
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:TCRootPath(TCPreferencesPath)];
        _enabled = [prefs[TCEnabledKey] boolValue];
        _activeTheme = [prefs[TCActiveThemeKey] copy];
        _enabledThemes = [prefs[TCEnabledThemesKey] isKindOfClass:NSArray.class]
            ? [prefs[TCEnabledThemesKey] copy] : @[];

        // 订阅刷新通知（SpringBoard 侧也监听 darwin 通知做整体刷新）
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self,
            TCThemeStoreDarwinCallback,
            (__bridge CFStringRef)TCReloadDarwinName,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);

        [self reload];

        // 内存压力清理
        _memoryPressureSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
            DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL,
            dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        if (_memoryPressureSource) {
            __weak typeof(self) weakSelf = self;
            dispatch_source_set_event_handler(_memoryPressureSource, ^{
                [weakSelf evictCaches];
            });
            dispatch_resume(_memoryPressureSource);
        }
    }
    return self;
}

static void TCThemeStoreDarwinCallback(CFNotificationCenterRef center, void *observer,
                                       CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    TCThemeStore *store = (__bridge TCThemeStore *)observer;
    [store reload];
}

#pragma mark - 主题扫描与合并

- (void)reload {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:TCRootPath(TCPreferencesPath)];
    self.enabled = [prefs[TCEnabledKey] boolValue];
    self.activeTheme = [prefs[TCActiveThemeKey] copy];
    self.enabledThemes = [prefs[TCEnabledThemesKey] isKindOfClass:NSArray.class]
        ? [prefs[TCEnabledThemesKey] copy] : @[];

    // 1) 扫描主题目录
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *themesDir = TCRootPath(TCThemesDirectoryName);
    NSMutableArray<TCTheme *> *found = [NSMutableArray array];
    for (NSString *entry in [fm contentsOfDirectoryAtPath:themesDir error:nil]) {
        if (![entry.pathExtension isEqualToString:@"theme"]) continue;
        NSString *path = [themesDir stringByAppendingPathComponent:entry];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) continue;
        [found addObject:[[TCTheme alloc] initWithPath:path]];
    }
    [found sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name"
                                                                ascending:YES
                                                                 selector:@selector(localizedStandardCompare:)]]];
    self.mThemes = found;

    // 2) 合并启用主题的资源到编译目录 /Library/ThemeCore
    NSString *storeDir = TCRootPath(TCStoreDirectoryName);
    [fm createDirectoryAtPath:storeDir withIntermediateDirectories:YES attributes:nil error:nil];

    [self.mIconPaths removeAllObjects];
    [self.mClockPaths removeAllObjects];
    [self.mShadowPaths removeAllObjects];
    [self.mThemeInfo removeAllObjects];

    BOOL shadowEnabled = NO;
    BOOL modern = NO;
    // 启用顺序：EnabledThemes 数组顺序，最后一个为 ActiveTheme（最上层）
    NSMutableArray<NSString *> *order = [self.enabledThemes mutableCopy] ?: [NSMutableArray array];
    if (self.activeTheme && ![order containsObject:self.activeTheme]) {
        [order addObject:self.activeTheme];
    }

    for (NSString *themeName in order) {
        TCTheme *theme = nil;
        for (TCTheme *t in found) {
            if ([t.name isEqualToString:themeName]) { theme = t; break; }
        }
        if (!theme) continue;
        if (theme.modern) modern = YES;
        if (theme.hasShadow) shadowEnabled = YES;
        [self _mergeTheme:theme storeDir:storeDir];
        // 合并 Info.plist 元信息
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                              [theme.path stringByAppendingPathComponent:@"Info.plist"]];
        for (NSString *k in info.allKeys) {
            self.mThemeInfo[k] = info[k];
        }
    }

    self.generation++;
    [self.imageCache removeAllObjects];

    // 注意：不在本方法内广播 reload 通知，避免自触发循环；
    // 由设置面板（或外部）发布 darwin 通知后，observer 回调再进入本方法。
}

/// 把一个主题的资源编译进 store 目录，路径登记到内存表
- (void)_mergeTheme:(TCTheme *)theme storeDir:(NSString *)storeDir {
    NSFileManager *fm = [NSFileManager defaultManager];

    // --- 图标 ---
    NSString *iconBundles = [theme.path stringByAppendingPathComponent:@"IconBundles"];
    NSArray<NSString *> *iconFiles = [fm contentsOfDirectoryAtPath:iconBundles error:nil];
    for (NSString *file in iconFiles) {
        if (![file.pathExtension isEqualToString:@"png"]) continue;
        NSString *identifier = [file stringByDeletingPathExtension];
        // 去掉 -large 后缀得到 app bundle id
        NSString *bundleID = [identifier stringByReplacingOccurrencesOfString:@"-large" withString:@""];
        [self _storePath:[iconBundles stringByAppendingPathComponent:file]
                storeDir:storeDir
              identifier:bundleID
                 inTable:self.mIconPaths
          overrideExisting:NO];
    }

    // Bundles/<bundleID>/Icon*.png 布局
    NSString *bundles = [theme.path stringByAppendingPathComponent:@"Bundles"];
    for (NSString *dir in [fm contentsOfDirectoryAtPath:bundles error:nil]) {
        NSString *dirPath = [bundles stringByAppendingPathComponent:dir];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:dirPath isDirectory:&isDir] || !isDir) continue;
        for (NSString *file in [fm contentsOfDirectoryAtPath:dirPath error:nil]) {
            if (![file.pathExtension isEqualToString:@"png"]) continue;
            [self _storePath:[dirPath stringByAppendingPathComponent:file]
                    storeDir:storeDir
                  identifier:dir
                     inTable:self.mIconPaths
              overrideExisting:NO];
        }
    }

    // --- 时钟 ---
    NSArray<NSString *> *clockKeys = @[
        @"clock.background", @"ClockIconBackgroundSquare",
        @"ClockIconSecondHand", @"ClockIconMinuteHand", @"ClockIconHourHand",
        @"ClockIconRedDot", @"ClockIconBlackDot"
    ];
    for (NSString *key in clockKeys) {
        NSString *src = [theme _findClockFileForKey:key];
        if (src) {
            [self _storeClockPath:src storeDir:storeDir key:key modern:theme.modern
                          inTable:self.mClockPaths overrideExisting:NO];
        }
    }

    // --- 阴影 ---
    NSString *shadowDir = [theme.path stringByAppendingPathComponent:@"Effects/Shadow"];
    for (NSString *file in [fm contentsOfDirectoryAtPath:shadowDir error:nil]) {
        if (![file.pathExtension isEqualToString:@"png"]) continue;
        NSString *identifier = [file stringByDeletingPathExtension];
        [self _storeShadowPath:[shadowDir stringByAppendingPathComponent:file]
                      storeDir:storeDir
                    identifier:identifier
                       inTable:self.mShadowPaths
                overrideExisting:NO];
    }
}

#pragma mark - 编译产物

/// 拷贝资源到 store，返回登记路径
- (nullable NSString *)_storePath:(NSString *)source storeDir:(NSString *)storeDir
                       identifier:(NSString *)identifier inTable:(NSMutableDictionary *)table
                 overrideExisting:(BOOL)overrideExisting {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:source]) return nil;
    if (table[identifier] && !overrideExisting) return table[identifier];

    NSString *digest = [self _digestOfFile:source];
    NSString *ext = source.pathExtension;
    NSString *dest = [storeDir stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%@.%@", digest, ext]];
    if (![fm fileExistsAtPath:dest]) {
        [fm copyItemAtPath:source toPath:dest error:nil];
    }
    table[identifier] = dest;
    return dest;
}

- (nullable NSString *)_storeClockPath:(NSString *)source storeDir:(NSString *)storeDir
                                   key:(NSString *)key modern:(BOOL)modern
                               inTable:(NSMutableDictionary *)table
                       overrideExisting:(BOOL)overrideExisting {
    return [self _storePath:source storeDir:storeDir identifier:key inTable:table
             overrideExisting:overrideExisting];
}

- (nullable NSString *)_storeShadowPath:(NSString *)source storeDir:(NSString *)storeDir
                             identifier:(NSString *)identifier inTable:(NSMutableDictionary *)table
                        overrideExisting:(BOOL)overrideExisting {
    return [self _storePath:source storeDir:storeDir identifier:identifier inTable:table
             overrideExisting:overrideExisting];
}

- (NSString *)_digestOfFile:(NSString *)path {
    // 用文件大小 + mtime + 路径生成缓存键（轻量、确定）
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attrs fileSize];
    NSDate *mtime = attrs[NSFileModificationDate] ?: [NSDate date];
    return [NSString stringWithFormat:@"%llx%08lx",
            size, (unsigned long)[path hash] ^ (unsigned long)[mtime timeIntervalSince1970]];
}

#pragma mark - 资源查询

- (UIImage *)imageForBundleIdentifier:(NSString *)bundleIdentifier scale:(CGFloat)scale {
    if (!self.enabled) return nil;
    NSString *key = [NSString stringWithFormat:@"icon|%@|%.2f|%lu",
                     [bundleIdentifier lowercaseString], scale, (unsigned long)self.generation];
    UIImage *cached = [self.imageCache objectForKey:key];
    if (cached) return cached;

    NSString *path = self.mIconPaths[[bundleIdentifier lowercaseString]];
    if (!path) return nil;

    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (image) {
        [self.imageCache setObject:image forKey:key cost:(NSUInteger)(image.size.width * image.size.height * 4)];
    }
    return image;
}

- (UIImage *)clockResourceForKey:(NSString *)key scale:(CGFloat)scale {
    if (!self.enabled) return nil;
    NSString *ckey = [NSString stringWithFormat:@"clock|%@|%.2f|%lu",
                      key, scale, (unsigned long)self.generation];
    UIImage *cached = [self.imageCache objectForKey:ckey];
    if (cached) return cached;

    NSString *path = self.mClockPaths[key];
    if (!path) return nil;
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (image) {
        [self.imageCache setObject:image forKey:ckey cost:(NSUInteger)(image.size.width * image.size.height * 4)];
    }
    return image;
}

- (UIImage *)shadowImageForScale:(CGFloat)scale {
    if (!self.enabled) return nil;
    NSString *key = [NSString stringWithFormat:@"shadow|%.2f|%lu", scale, (unsigned long)self.generation];
    UIImage *cached = [self.imageCache objectForKey:key];
    if (cached) return cached;

    // 通用阴影：取 ActiveTheme 的 shadow 表（优先各 app 专属，回退全局）
    NSString *path = self.mShadowPaths[@"Shadow"] ?: self.mShadowPaths[@"IconShadow"];
    if (!path) return nil;
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (image) {
        [self.imageCache setObject:image forKey:key cost:(NSUInteger)(image.size.width * image.size.height * 4)];
    }
    return image;
}

- (BOOL)hasShadow {
    return self.enabled && self.mShadowPaths.count > 0;
}

- (BOOL)isModern {
    return self.enabled;
}

- (NSArray<TCTheme *> *)themes {
    return [self.mThemes copy];
}

- (NSDictionary<NSString *, NSString *> *)iconPaths {
    return [self.mIconPaths copy];
}

- (NSDictionary<NSString *, NSString *> *)clockPaths {
    return [self.mClockPaths copy];
}

- (NSDictionary<NSString *, NSString *> *)resolvedShadowPaths {
    return [self.mShadowPaths copy];
}

- (NSDictionary<NSString *, id> *)themeInfo {
    return [self.mThemeInfo copy];
}

- (void)evictCaches {
    [self.imageCache removeAllObjects];
}

@end
