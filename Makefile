include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = DeviceSpoofer
DeviceSpoofer_FILES = Tweak.xm fishhook.c
DeviceSpoofer_CFLAGS = -fobjc-arc
DeviceSpoofer_LDFLAGS = -framework UIKit -framework AdSupport -framework CoreFoundation

include $(THEOS_MAKE_PATH)/library.mk
