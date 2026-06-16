include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DeviceSpoofer
DeviceSpoofer_FILES = Tweak.xm
DeviceSpoofer_CFLAGS = -fobjc-arc
DeviceSpoofer_LDFLAGS = -framework UIKit -framework AdSupport -framework CoreFoundation

include $(THEOS_MAKE_PATH)/tweak.mk
