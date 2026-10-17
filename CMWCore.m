//
//  CMWCore.m
//  CameraWatermark
//

#import "CMWCore.h"
#import <sys/sysctl.h>
#import <stdlib.h>
#import <math.h>

static NSString *const CMWPreferencesDomain = @"com.dsh.camerawatermark";
static NSString *const CMWMarker = @"CMW1";

#pragma mark - 配置

static NSDictionary *CMWPreferences(void) {
    CFPropertyListRef copied = CFPreferencesCopyMultiple(
        NULL, (__bridge CFStringRef)CMWPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (copied != NULL && CFGetTypeID(copied) == CFDictionaryGetTypeID()) {
        return (__bridge_transfer NSDictionary *)copied;
    }
    if (copied != NULL) {
        CFRelease(copied);
    }
    return @{};
}

static BOOL CMWEnabled(void) {
    id value = CMWPreferences()[@"Enabled"];
    return value != nil ? [value boolValue] : YES;
}

#pragma mark - 标记

BOOL CMWPropertiesHaveMarker(CFDictionaryRef properties) {
    if (properties == NULL) {
        return NO;
    }
    CFDictionaryRef exif = CFDictionaryGetValue(properties, kCGImagePropertyExifDictionary);
    if (exif == NULL || CFGetTypeID(exif) != CFDictionaryGetTypeID()) {
        return NO;
    }
    CFStringRef comment = CFDictionaryGetValue(exif, kCGImagePropertyExifUserComment);
    if (comment == NULL || CFGetTypeID(comment) != CFStringGetTypeID()) {
        return NO;
    }
    return CFStringCompare(comment, CFSTR("CMW1"), 0) == kCFCompareEqualTo;
}

static NSDictionary *CMWPropertiesWithMarker(NSDictionary *properties) {
    NSMutableDictionary *result = properties != nil ? [properties mutableCopy] : [NSMutableDictionary dictionary];
    NSDictionary *exif = result[(__bridge NSString *)kCGImagePropertyExifDictionary];
    NSMutableDictionary *mutableExif = [exif isKindOfClass:[NSDictionary class]]
        ? [exif mutableCopy]
        : [NSMutableDictionary dictionary];
    mutableExif[(__bridge NSString *)kCGImagePropertyExifUserComment] = CMWMarker;
    result[(__bridge NSString *)kCGImagePropertyExifDictionary] = mutableExif;
    return result;
}

#pragma mark - 机型

static NSString *CMWMachineIdentifier(void) {
    static NSString *identifier;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size_t size = 0;
        if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0) {
            return;
        }
        char *buffer = malloc(size);
        if (buffer == NULL) {
            return;
        }
        if (sysctlbyname("hw.machine", buffer, &size, NULL, 0) == 0) {
            identifier = [NSString stringWithUTF8String:buffer];
        }
        free(buffer);
    });
    return identifier ?: @"";
}

static NSString *CMWDeviceModel(void) {
    static NSDictionary<NSString *, NSString *> *models;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        models = @{
            @"iPhone10,1": @"iPhone 8", @"iPhone10,4": @"iPhone 8",
            @"iPhone10,2": @"iPhone 8 Plus", @"iPhone10,5": @"iPhone 8 Plus",
            @"iPhone10,3": @"iPhone X", @"iPhone10,6": @"iPhone X",
            @"iPhone11,2": @"iPhone XS",
            @"iPhone11,4": @"iPhone XS Max", @"iPhone11,6": @"iPhone XS Max",
            @"iPhone11,8": @"iPhone XR",
            @"iPhone12,1": @"iPhone 11",
            @"iPhone12,3": @"iPhone 11 Pro", @"iPhone12,5": @"iPhone 11 Pro Max",
            @"iPhone12,8": @"iPhone SE (2nd)",
            @"iPhone13,1": @"iPhone 12 mini", @"iPhone13,2": @"iPhone 12",
            @"iPhone13,3": @"iPhone 12 Pro", @"iPhone13,4": @"iPhone 12 Pro Max",
            @"iPhone14,2": @"iPhone 13 Pro", @"iPhone14,3": @"iPhone 13 Pro Max",
            @"iPhone14,4": @"iPhone 13 mini", @"iPhone14,5": @"iPhone 13",
            @"iPhone14,6": @"iPhone SE (3rd)",
            @"iPhone14,7": @"iPhone 14", @"iPhone14,8": @"iPhone 14 Plus",
            @"iPhone15,2": @"iPhone 14 Pro", @"iPhone15,3": @"iPhone 14 Pro Max",
            @"iPhone15,4": @"iPhone 15", @"iPhone15,5": @"iPhone 15 Plus",
            @"iPhone16,1": @"iPhone 15 Pro", @"iPhone16,2": @"iPhone 15 Pro Max",
        };
    });

    NSString *name = models[CMWMachineIdentifier()];
    if (name.length > 0) {
        return name;
    }
    NSString *model = [UIDevice currentDevice].model;
    return model.length > 0 ? model : @"iPhone";
}

#pragma mark - EXIF / 日期 / GPS

static NSDateFormatter *CMWDateFormatter(NSString *format) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = format;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return formatter;
}

static NSString *CMWDateString(NSDictionary *properties) {
    NSDictionary *exif = properties[(__bridge NSString *)kCGImagePropertyExifDictionary];
    NSString *original = [exif isKindOfClass:[NSDictionary class]]
        ? exif[(__bridge NSString *)kCGImagePropertyExifDateTimeOriginal]
        : nil;

    NSDate *date = nil;
    if (original.length > 0) {
        date = [CMWDateFormatter(@"yyyy:MM:dd HH:mm:ss") dateFromString:original];
    }
    if (date == nil) {
        date = [NSDate date];
    }
    return [CMWDateFormatter(@"yyyy.MM.dd HH:mm:ss") stringFromDate:date];
}

static NSString *CMWNumberString(double value) {
    if (value <= 0) {
        return nil;
    }
    if (fabs(value - round(value)) < 0.05) {
        return [NSString stringWithFormat:@"%ld", (long)llround(value)];
    }
    return [NSString stringWithFormat:@"%.1f", value];
}

static NSString *CMWExifString(NSDictionary *properties) {
    NSDictionary *exif = properties[(__bridge NSString *)kCGImagePropertyExifDictionary];
    if (![exif isKindOfClass:[NSDictionary class]]) {
        return @"";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray array];

    id focal = exif[(__bridge NSString *)kCGImagePropertyExifFocalLength];
    if ([focal isKindOfClass:[NSNumber class]]) {
        NSString *value = CMWNumberString([focal doubleValue]);
        if (value.length > 0) {
            [parts addObject:[value stringByAppendingString:@"mm"]];
        }
    }

    id fNumber = exif[(__bridge NSString *)kCGImagePropertyExifFNumber];
    if ([fNumber isKindOfClass:[NSNumber class]]) {
        NSString *value = CMWNumberString([fNumber doubleValue]);
        if (value.length > 0) {
            [parts addObject:[@"f/" stringByAppendingString:value]];
        }
    }

    id exposure = exif[(__bridge NSString *)kCGImagePropertyExifExposureTime];
    if ([exposure isKindOfClass:[NSNumber class]]) {
        double seconds = [exposure doubleValue];
        if (seconds > 0) {
            if (seconds < 1.0) {
                long denominator = (long)llround(1.0 / seconds);
                [parts addObject:[NSString stringWithFormat:@"1/%lds", denominator]];
            } else {
                [parts addObject:[NSString stringWithFormat:@"%.1fs", seconds]];
            }
        }
    }

    id iso = exif[(__bridge NSString *)kCGImagePropertyExifISOSpeedRatings];
    if ([iso isKindOfClass:[NSArray class]] && [(NSArray *)iso count] > 0) {
        id first = [(NSArray *)iso firstObject];
        if ([first isKindOfClass:[NSNumber class]]) {
            [parts addObject:[NSString stringWithFormat:@"ISO%ld", (long)[first integerValue]]];
        }
    }

    return [parts componentsJoinedByString:@" "];
}

static NSString *CMWCoordinate(NSArray *value, NSString *reference) {
    if (![value isKindOfClass:[NSArray class]] || value.count < 2) {
        return nil;
    }
    double degrees = [value[0] doubleValue];
    double minutes = [value[1] doubleValue];
    double seconds = value.count > 2 ? [value[2] doubleValue] : 0;
    NSString *suffix = [reference isKindOfClass:[NSString class]] ? reference : @"";
    return [NSString stringWithFormat:@"%d°%d'%d\"%@",
                                      (int)degrees, (int)minutes, (int)llround(seconds), suffix];
}

static NSString *CMWGPSString(NSDictionary *properties) {
    NSDictionary *gps = properties[(__bridge NSString *)kCGImagePropertyGPSDictionary];
    if (![gps isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    NSString *latitude = CMWCoordinate(gps[(__bridge NSString *)kCGImagePropertyGPSLatitude],
                                       gps[(__bridge NSString *)kCGImagePropertyGPSLatitudeRef]);
    NSString *longitude = CMWCoordinate(gps[(__bridge NSString *)kCGImagePropertyGPSLongitude],
                                        gps[(__bridge NSString *)kCGImagePropertyGPSLongitudeRef]);
    if (latitude.length == 0 || longitude.length == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"%@ %@", latitude, longitude];
}

#pragma mark - 绘制

static void CMWDrawWatermark(CGSize size, NSDictionary *properties) {
    CGFloat width = size.width;
    CGFloat height = size.height;
    if (width <= 0 || height <= 0) {
        return;
    }

    CGFloat margin = width * 0.028;
    CGFloat barWidth = width - margin * 2;
    CGFloat barHeight = MIN(height * 0.115, barWidth * 0.135);
    if (barHeight < 36) {
        barHeight = MAX(36, height * 0.07);
    }
    CGFloat barX = margin;
    CGFloat barY = height - margin - barHeight;

    UIBezierPath *background = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(barX, barY, barWidth, barHeight)
                                                             cornerRadius:barHeight * 0.30];
    [[UIColor colorWithWhite:0.0 alpha:0.38] setFill];
    [background fill];
    [[UIColor colorWithWhite:1.0 alpha:0.12] setStroke];
    background.lineWidth = MAX(1.0, barHeight * 0.008);
    [background stroke];

    CGFloat padding = barHeight * 0.13;
    CGFloat modelSize = barHeight * 0.27;
    CGFloat smallSize = barHeight * 0.165;

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentLeft;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;

    NSDictionary *modelAttributes = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:modelSize],
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSParagraphStyleAttributeName: paragraph,
    };
    NSDictionary *smallAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:smallSize],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.88],
        NSParagraphStyleAttributeName: paragraph,
    };

    [CMWDeviceModel() drawAtPoint:CGPointMake(barX + padding, barY + barHeight * 0.17)
                  withAttributes:modelAttributes];
    [CMWDateString(properties) drawAtPoint:CGPointMake(barX + padding, barY + barHeight * 0.57)
                           withAttributes:smallAttributes];

    CGFloat dividerX = barX + barWidth * 0.60;
    UIBezierPath *divider = [UIBezierPath bezierPath];
    [divider moveToPoint:CGPointMake(dividerX, barY + barHeight * 0.22)];
    [divider addLineToPoint:CGPointMake(dividerX, barY + barHeight * 0.78)];
    [[UIColor colorWithWhite:1.0 alpha:0.28] setStroke];
    divider.lineWidth = MAX(1.0, barHeight * 0.008);
    [divider stroke];

    NSDictionary *logoAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:barHeight * 0.30],
        NSForegroundColorAttributeName: [UIColor whiteColor],
    };
    NSString *logo = @"\uF8FF";
    CGSize logoSize = [logo sizeWithAttributes:logoAttributes];
    [logo drawAtPoint:CGPointMake(dividerX - logoSize.width - barHeight * 0.10,
                                  barY + (barHeight - logoSize.height) * 0.5)
       withAttributes:logoAttributes];

    CGFloat textX = dividerX + barHeight * 0.14;
    NSString *exif = CMWExifString(properties);
    if (exif.length > 0) {
        [exif drawAtPoint:CGPointMake(textX, barY + barHeight * 0.17) withAttributes:smallAttributes];
    }
    NSString *gps = CMWGPSString(properties);
    if (gps.length > 0) {
        [gps drawAtPoint:CGPointMake(textX, barY + barHeight * 0.57) withAttributes:smallAttributes];
    }
}

CGImageRef CMWCreateWatermarkedImage(CGImageRef image, CFDictionaryRef properties) {
    if (image == NULL || !CMWEnabled()) {
        return NULL;
    }
    size_t pixelWidth = CGImageGetWidth(image);
    size_t pixelHeight = CGImageGetHeight(image);
    if (MAX(pixelWidth, pixelHeight) < 1600) {
        return NULL;
    }

    NSDictionary *props = properties != NULL ? (__bridge NSDictionary *)properties : @{};
    NSNumber *orientationValue = props[(__bridge NSString *)kCGImagePropertyOrientation];
    UIImageOrientation orientation = (UIImageOrientation)(orientationValue != nil
                                                          ? orientationValue.integerValue
                                                          : UIImageOrientationUp);
    UIImage *source = [UIImage imageWithCGImage:image scale:1.0 orientation:orientation];
    if (source == nil) {
        return NULL;
    }

    CGSize size = source.size;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *result = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [source drawInRect:CGRectMake(0, 0, size.width, size.height)];
        CMWDrawWatermark(size, props);
    }];

    return result != nil ? CGImageRetain(result.CGImage) : NULL;
}

#pragma mark - 数据

NSData *CMWWatermarkImageData(NSData *data) {
    if (data.length == 0 || !CMWEnabled()) {
        return nil;
    }

    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (source == NULL) {
        return nil;
    }
    NSDictionary *props = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    if (props == nil) {
        props = @{};
    }
    if (CMWPropertiesHaveMarker((__bridge CFDictionaryRef)props)) {
        CFRelease(source);
        return nil;
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (image == NULL) {
        return nil;
    }

    CGImageRef watermarked = CMWCreateWatermarkedImage(image, (__bridge CFDictionaryRef)props);
    CGImageRelease(image);
    if (watermarked == NULL) {
        return nil;
    }

    NSMutableData *result = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)result, CFSTR("public.jpeg"), 1, NULL);
    if (destination == NULL) {
        CGImageRelease(watermarked);
        return nil;
    }
    NSDictionary *markedProperties = CMWPropertiesWithMarker(props);
    CGImageDestinationAddImage(destination, watermarked, (__bridge CFDictionaryRef)markedProperties);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(watermarked);

    return result.length > 0 ? result : nil;
}

#pragma mark - 注入

typedef void (*CMWAddImageFunction)(CGImageDestinationRef, CGImageRef, CFDictionaryRef);
typedef void (*CMWAddImageFromSourceFunction)(CGImageDestinationRef, CGImageSourceRef, size_t, CFDictionaryRef);

static CMWAddImageFunction CMWOriginalAddImage = NULL;
static CMWAddImageFromSourceFunction CMWOriginalAddImageFromSource = NULL;

extern void MSHookFunction(void *symbol, void *replace, void **result);

static void CMWAddImageHook(CGImageDestinationRef destination, CGImageRef image, CFDictionaryRef properties) {
    if (CMWOriginalAddImage == NULL) {
        return;
    }
    if (CMWPropertiesHaveMarker(properties)) {
        CMWOriginalAddImage(destination, image, properties);
        return;
    }

    CGImageRef watermarked = CMWCreateWatermarkedImage(image, properties);
    if (watermarked == NULL) {
        CMWOriginalAddImage(destination, image, properties);
        return;
    }
    NSDictionary *markedProperties = CMWPropertiesWithMarker(
        properties != NULL ? (__bridge NSDictionary *)properties : @{});
    CMWOriginalAddImage(destination, watermarked, (__bridge CFDictionaryRef)markedProperties);
    CGImageRelease(watermarked);
}

static void CMWAddImageFromSourceHook(CGImageDestinationRef destination,
                                      CGImageSourceRef source,
                                      size_t index,
                                      CFDictionaryRef properties) {
    if (CMWOriginalAddImage == NULL || CMWOriginalAddImageFromSource == NULL) {
        return;
    }

    NSDictionary *props = properties != NULL ? (__bridge NSDictionary *)properties : nil;
    if (props == nil) {
        props = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, index, NULL));
    }
    if (props == nil) {
        props = @{};
    }
    if (CMWPropertiesHaveMarker((__bridge CFDictionaryRef)props)) {
        CMWOriginalAddImageFromSource(destination, source, index, properties);
        return;
    }

    CGImageRef image = CGImageSourceCreateImageAtIndex(source, index, NULL);
    if (image == NULL) {
        CMWOriginalAddImageFromSource(destination, source, index, properties);
        return;
    }
    CGImageRef watermarked = CMWCreateWatermarkedImage(image, (__bridge CFDictionaryRef)props);
    CGImageRelease(image);
    if (watermarked == NULL) {
        CMWOriginalAddImageFromSource(destination, source, index, properties);
        return;
    }

    NSDictionary *markedProperties = CMWPropertiesWithMarker(props);
    CMWOriginalAddImage(destination, watermarked, (__bridge CFDictionaryRef)markedProperties);
    CGImageRelease(watermarked);
}

void CMWInstallHooks(void) {
    if (!CMWEnabled()) {
        return;
    }
    MSHookFunction((void *)CGImageDestinationAddImage,
                   (void *)CMWAddImageHook,
                   (void **)&CMWOriginalAddImage);
    MSHookFunction((void *)CGImageDestinationAddImageFromSource,
                   (void *)CMWAddImageFromSourceHook,
                   (void **)&CMWOriginalAddImageFromSource);
}

BOOL CMWIsEligibleProcess(void) {
    return [[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.camera"];
}
