.PHONY: release dmg build-macos clean-dmg

APP_NAME := scriptvault
VOLUME_NAME := ScriptVault
RELEASE_DIR := build/macos/Build/Products/Release
APP_PATH := $(RELEASE_DIR)/$(APP_NAME).app
DIST_DIR := build/dist
DMG_STAGING_DIR := $(DIST_DIR)/dmg
DMG_PATH := $(DIST_DIR)/$(APP_NAME).dmg

release: dmg

dmg: build-macos
	rm -rf "$(DMG_STAGING_DIR)" "$(DMG_PATH)"
	mkdir -p "$(DMG_STAGING_DIR)" "$(DIST_DIR)"
	cp -R "$(APP_PATH)" "$(DMG_STAGING_DIR)/"
	ln -s /Applications "$(DMG_STAGING_DIR)/Applications"
	hdiutil create \
		-volname "$(VOLUME_NAME)" \
		-srcfolder "$(DMG_STAGING_DIR)" \
		-ov \
		-format UDZO \
		"$(DMG_PATH)"
	@echo "Created $(DMG_PATH)"

build-macos:
	fvm flutter build macos

clean-dmg:
	rm -rf "$(DMG_STAGING_DIR)" "$(DMG_PATH)"
