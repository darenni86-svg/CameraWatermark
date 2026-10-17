export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64 arm64e
export DEBUG = 0
export FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CameraWatermark

CameraWatermark_FILES = Tweak.xm CMWCore.m
CameraWatermark_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations
CameraWatermark_FRAMEWORKS = UIKit Foundation CoreGraphics ImageIO Photos

include $(THEOS_MAKE_PATH)/tweak.mk
