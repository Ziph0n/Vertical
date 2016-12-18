TARGET = iphone:9.2

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Vertical
Vertical_FILES = Tweak.xm CBAutoScrollLabel/CBAutoScrollLabel.m RSPlayPauseButton/RSPlayPauseButton.m
Vertical_PRIVATE_FRAMEWORKS = MediaRemote MediaPlayerUI
Vertical_FRAMEWORKS = Social
Vertical_LIBRARIES = Cephei

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += vertical
include $(THEOS_MAKE_PATH)/aggregate.mk
