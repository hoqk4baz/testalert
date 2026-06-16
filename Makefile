TARGET := iphone:clang:latest:13.0
ARCHS = arm64

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DeviceSpoofer

DeviceSpoofer_FILES = Tweak.xm
DeviceSpoofer_CFLAGS = -fobjc-arc
DeviceSpoofer_LDFLAGS += -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
