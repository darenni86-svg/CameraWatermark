//
//  Tweak.xm
//  CameraWatermark
//

#import <UIKit/UIKit.h>
#import "CMWCore.h"

// 不直接 import <Photos/Photos.h>：该头文件要求 Objective-C++，
// 这里只声明实际用到的类和枚举，运行时由系统 Photos.framework 提供。
typedef NS_ENUM(NSInteger, CMWAssetResourceType) {
    CMWAssetResourceTypePhoto = 1,
};

@interface PHAssetCreationRequest : NSObject
- (void)addResourceWithType:(CMWAssetResourceType)type data:(NSData *)data options:(id)options;
@end

%group CameraWatermarkHooks

%hook PHAssetCreationRequest

- (void)addResourceWithType:(CMWAssetResourceType)type
                       data:(NSData *)data
                    options:(id)options {
    if (type == CMWAssetResourceTypePhoto) {
        NSData *watermarked = CMWWatermarkImageData(data);
        if (watermarked.length > 0) {
            %orig(type, watermarked, options);
            return;
        }
    }
    %orig;
}

%end

%end

%ctor {
    @autoreleasepool {
        if (!CMWIsEligibleProcess()) {
            return;
        }
        CMWInstallHooks();
        %init(CameraWatermarkHooks);
    }
}
