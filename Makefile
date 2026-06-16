include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = DeviceSpoofer
DeviceSpoofer_FILES = Tweak.xm fishhook.c
DeviceSpoofer_CFLAGS = -fobjc-arc -Wno-error
DeviceSpoofer_LDFLAGS = -framework UIKit -framework AdSupport -framework CoreFoundation

# ÖNEMLİ: Sadece arm64 build et (armv7'yi kaldır)
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:12.0   # Minimum iOS 12

include $(THEOS_MAKE_PATH)/library.mk
