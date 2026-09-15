#import "TCClockResource.h"
#import "TCThemeStore.h"

@implementation TCClockResource {
    UIImage *_background;
    UIImage *_hourHand;
    UIImage *_minuteHand;
    UIImage *_secondHand;
    UIImage *_redDot;       // 秒针端圆点
    UIImage *_blackDot;     // 中心圆点
}

+ (nullable instancetype)currentResource {
    TCThemeStore *store = TCThemeStore.sharedStore;
    if (!store.enabled || !store.clockPaths.count) return nil;

    TCClockResource *r = [[TCClockResource alloc] init];
    r->_modern = store.isModern;
    r->_background = [store clockResourceForKey:@"clock.background" scale:UIScreen.mainScreen.scale];
    if (!r->_background) {
        r->_background = [store clockResourceForKey:@"ClockIconBackgroundSquare" scale:UIScreen.mainScreen.scale];
    }
    r->_hourHand   = [store clockResourceForKey:@"ClockIconHourHand" scale:UIScreen.mainScreen.scale];
    r->_minuteHand = [store clockResourceForKey:@"ClockIconMinuteHand" scale:UIScreen.mainScreen.scale];
    r->_secondHand = [store clockResourceForKey:@"ClockIconSecondHand" scale:UIScreen.mainScreen.scale];
    r->_redDot     = [store clockResourceForKey:@"ClockIconRedDot" scale:UIScreen.mainScreen.scale];
    r->_blackDot   = [store clockResourceForKey:@"ClockIconBlackDot" scale:UIScreen.mainScreen.scale];
    r->_hasBackground = r->_background != nil;

    // 至少需要指针素材才有效
    if (!r->_hourHand && !r->_minuteHand) return nil;
    return r;
}

- (UIImage *)imageForDate:(NSDate *)date scale:(CGFloat)scale {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c = [cal components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
                                 fromDate:date];
    CGFloat hourAngle   = ((c.hour % 12) + c.minute / 60.0) / 12.0 * 2 * M_PI;
    CGFloat minuteAngle = (c.minute + c.second / 60.0) / 60.0 * 2 * M_PI;
    CGFloat secondAngle = c.second / 60.0 * 2 * M_PI;

    // 以背景（或指针）尺寸为画布
    UIImage *base = _background ?: _hourHand;
    if (!base) return nil;
    CGSize size = base.size;

    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) { UIGraphicsEndImageContext(); return nil; }

    [base drawInRect:CGRectMake(0, 0, size.width, size.height)];

    CGPoint center = CGPointMake(size.width / 2.0, size.height / 2.0);
    [self _drawHand:_hourHand   angle:hourAngle   center:center context:ctx];
    [self _drawHand:_minuteHand angle:minuteAngle center:center context:ctx];
    [self _drawHand:_secondHand angle:secondAngle center:center context:ctx];

    if (_redDot) {
        CGRect r = CGRectMake(center.x - _redDot.size.width / 2.0, center.y - _redDot.size.height / 2.0,
                              _redDot.size.width, _redDot.size.height);
        [_redDot drawInRect:r];
    }
    if (_blackDot) {
        CGRect r = CGRectMake(center.x - _blackDot.size.width / 2.0, center.y - _blackDot.size.height / 2.0,
                              _blackDot.size.width, _blackDot.size.height);
        [_blackDot drawInRect:r];
    }

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)_drawHand:(UIImage *)hand angle:(CGFloat)angle center:(CGPoint)center context:(CGContextRef)ctx {
    if (!hand || !ctx) return;
    CGSize size = hand.size;

    // 指针素材按“竖直朝上、锚点在下端”绘制，绕中心旋转
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, center.x, center.y);
    CGContextRotateCTM(ctx, angle);
    CGRect rect = CGRectMake(-size.width / 2.0, -size.height, size.width, size.height);
    [hand drawInRect:rect];
    CGContextRestoreGState(ctx);
}

@end
