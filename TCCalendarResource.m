#import "TCCalendarResource.h"
#import "TCThemeStore.h"

/// 日历数字区域的可调参数（与 iOS 日历图标布局对应）
static NSString *const TCCalendarDateSettingsKey = @"CalendarIconDateSettings";
static NSString *const TCCalendarDaySettingsKey  = @"CalendarIconDaySettings";

@interface TCCalendarResource ()
@property (nonatomic, strong) UIImage *background;
@property (nonatomic, strong) NSDictionary *dateSettings;   // 数字布局参数
@property (nonatomic, strong) NSDictionary *daySettings;    // 星期布局参数
@end

@implementation TCCalendarResource

+ (nullable instancetype)currentResource {
    TCThemeStore *store = TCThemeStore.sharedStore;
    UIImage *bg = [store imageForBundleIdentifier:@"com.apple.mobilecal" scale:UIScreen.mainScreen.scale];
    if (!bg) return nil;

    TCCalendarResource *r = [[TCCalendarResource alloc] init];
    r->_background = bg;
    r->_dateSettings = store.themeInfo[TCCalendarDateSettingsKey] ?: @{};
    r->_daySettings = store.themeInfo[TCCalendarDaySettingsKey] ?: @{};
    return r;
}

- (UIImage *)imageForDate:(NSDate *)date scale:(CGFloat)scale {
    if (!_background) return nil;
    CGSize size = _background.size;

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) { UIGraphicsEndImageContext(); return nil; }

    [_background drawInRect:CGRectMake(0, 0, size.width, size.height)];

    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c = [cal components:(NSCalendarUnitDay | NSCalendarUnitWeekday) fromDate:date];
    NSString *day = [NSString stringWithFormat:@"%ld", (long)c.day];
    NSString *week = [self _weekdayName:c.weekday];

    // 主题可覆盖字号/颜色/偏移（单位为图标内相对坐标，默认按 iOS 布局）
    UIFont *dateFont = [self _fontForKey:@"FontName" weight:@"FontWeight" size:@"FontSize"
                             defaultSize:size.height * 0.30];
    UIColor *dateColor = [self _colorForKey:@"TextColor" defaultColor:[UIColor blackColor]];
    UIFont *weekFont  = [UIFont systemFontOfSize:size.height * 0.12 weight:UIFontWeightMedium];
    UIColor *weekColor = [UIColor blackColor];

    CGPoint dateOrigin = [self _offsetForKey:@"TextXoffset" yKey:@"TextYoffset"
                                     defaultX:size.width * 0.5 - dateFont.pointSize * 0.55
                                     defaultY:size.height * 0.30];
    [day drawAtPoint:dateOrigin
           withAttributes:@{NSFontAttributeName: dateFont, NSForegroundColorAttributeName: dateColor}];
    [week drawAtPoint:CGPointMake(size.width * 0.5 - weekFont.pointSize * 0.45, size.height * 0.16)
           withAttributes:@{NSFontAttributeName: weekFont, NSForegroundColorAttributeName: weekColor}];

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (NSString *)_weekdayName:(NSInteger)weekday {
    NSArray *names = @[@"", @"日", @"一", @"二", @"三", @"四", @"五", @"六"];
    return weekday >= 1 && weekday <= 7 ? names[weekday] : @"";
}

- (UIFont *)_fontForKey:(NSString *)nameKey weight:(NSString *)weightKey size:(NSString *)sizeKey
             defaultSize:(CGFloat)defaultSize {
    CGFloat size = [_dateSettings[sizeKey] doubleValue] ?: defaultSize;
    NSString *fontName = _dateSettings[nameKey];
    UIFont *font = fontName ? [UIFont fontWithName:fontName size:size] : nil;
    if (!font) {
        UIFontWeight weight = UIFontWeightRegular;
        NSString *w = _dateSettings[weightKey];
        if ([w isEqualToString:@"ultralight"]) weight = UIFontWeightUltraLight;
        else if ([w isEqualToString:@"thin"]) weight = UIFontWeightThin;
        else if ([w isEqualToString:@"light"]) weight = UIFontWeightLight;
        else if ([w isEqualToString:@"medium"]) weight = UIFontWeightMedium;
        else if ([w isEqualToString:@"semibold"]) weight = UIFontWeightSemibold;
        else if ([w isEqualToString:@"demibold"]) weight = UIFontWeightSemibold;
        else if ([w isEqualToString:@"bold"]) weight = UIFontWeightBold;
        else if ([w isEqualToString:@"heavy"]) weight = UIFontWeightHeavy;
        else if ([w isEqualToString:@"black"]) weight = UIFontWeightBlack;
        font = [UIFont systemFontOfSize:size weight:weight];
    }
    return font;
}

- (UIColor *)_colorForKey:(NSString *)key defaultColor:(UIColor *)def {
    NSString *hex = _dateSettings[key];
    if (![hex isKindOfClass:NSString.class] || hex.length < 6) return def;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    unsigned long long value = 0;
    if (![scanner scanHexLongLong:&value]) return def;
    return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
                           green:((value >> 8) & 0xFF) / 255.0
                            blue:(value & 0xFF) / 255.0
                           alpha:1.0];
}

- (CGPoint)_offsetForKey:(NSString *)xKey yKey:(NSString *)yKey
                defaultX:(CGFloat)dx defaultY:(CGFloat)dy {
    CGFloat x = [_dateSettings[xKey] doubleValue] ?: dx;
    CGFloat y = [_dateSettings[yKey] doubleValue] ?: dy;
    return CGPointMake(x, y);
}

@end
