//
//  CMWCore.h
//  CameraWatermark
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

NS_ASSUME_NONNULL_BEGIN

BOOL CMWIsEligibleProcess(void);
void CMWInstallHooks(void);

CGImageRef _Nullable CMWCreateWatermarkedImage(CGImageRef image, CFDictionaryRef _Nullable properties);
NSData * _Nullable CMWWatermarkImageData(NSData *data);
BOOL CMWPropertiesHaveMarker(CFDictionaryRef _Nullable properties);

NS_ASSUME_NONNULL_END
