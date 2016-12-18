TARGET = iphone:9.2

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Vertical
Vertical_FILES = VerticalRootListController.m
Vertical_INSTALL_PATH = /Library/PreferenceBundles
Vertical_FRAMEWORKS = UIKit
Vertical_LIBRARIES = CepheiPrefs Cephei
Vertical_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/Vertical.plist$(ECHO_END)
