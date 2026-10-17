//
//  Tweak.xm
//  CameraWatermark
//

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "CMWCore.h"

%group CameraWatermarkHooks

%hook PHAssetCreationRequest

- (void)addResourceWithType:(PHAssetResourceType)type
                       data:(NSData *)data
                    options:(PHAssetResourceCreationOptions *)options {
    if (type == PHAssetResourceTypePhoto) {
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
