#import "TCIconImageBox.h"
#import "TCThemeStore.h"
#import <ImageIO/ImageIO.h>

@implementation TCIconImageBox {
    CGImageRef _imageRef;
}

static NSCache<NSString *, TCIconImageBox *> *gBoxCache;

+ (void)initialize {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gBoxCache = [[NSCache alloc] init];
        gBoxCache.countLimit = 256;
    });
}

- (void)dealloc {
    if (_imageRef) CGImageRelease(_imageRef);
}

+ (nullable instancetype)imageBoxForBundleIdentifier:(NSString *)bundleIdentifier
                                               scale:(CGFloat)scale
                                         minimumSize:(CGSize)minimumSize {
    if (!bundleIdentifier.length) return nil;

    NSString *cacheKey = [NSString stringWithFormat:@"%lu|%@|%ux%u@%.0f|%@",
                          (unsigned long)TCThemeStore.sharedStore.generation,
                          bundleIdentifier,
                          (unsigned)minimumSize.width, (unsigned)minimumSize.height,
                          scale,
                          @(TCThemeStore.sharedStore.enabled)];

    TCIconImageBox *cached = [gBoxCache objectForKey:cacheKey];
    if (cached) return cached;

    UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:bundleIdentifier scale:scale];
    if (!themed) return nil;

    CGImageRef cg = CGImageRetain(themed.CGImage);
    TCIconImageBox *box = [[TCIconImageBox alloc] initWithCGImage:cg
                                                            scale:scale
                                                      minimumSize:minimumSize
                                                      placeholder:NO];
    CGImageRelease(cg);
    if (box) {
        [gBoxCache setObject:box forKey:cacheKey];
    }
    return box;
}

+ (nullable instancetype)imageBoxWithCGImage:(CGImageRef)cgImage
                                       scale:(CGFloat)scale
                                 minimumSize:(CGSize)minimumSize
                                 placeholder:(BOOL)placeholder {
    if (!cgImage) return nil;
    return [[self alloc] initWithCGImage:cgImage scale:scale minimumSize:minimumSize placeholder:placeholder];
}

- (nullable instancetype)initWithCGImage:(CGImageRef)cgImage
                                   scale:(CGFloat)scale
                             minimumSize:(CGSize)minimumSize
                             placeholder:(BOOL)placeholder {
    self = [super init];
    if (self) {
        _imageRef = CGImageRetain(cgImage);
        _pixelSize = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
        _placeholder = placeholder;
    }
    return self;
}

- (CGImageRef)image {
    return _imageRef;
}

- (void)clearCache {
    [gBoxCache removeAllObjects];
}

@end
