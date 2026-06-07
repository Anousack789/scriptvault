.PHONY: run release release-version release-info release-preflight check-cocoapods disable-swift-package-manager dmg build-macos verify-release clean-dmg version bump-version bump-major bump-minor bump-patch version-control vc

APP_ID := scriptvault
APP_NAME := ScriptVault
FLUTTER ?= .fvm/flutter_sdk/bin/flutter
PART ?= patch
PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)
PUBSPEC_VERSION := $(shell sed -n 's/^version:[[:space:]]*//p' pubspec.yaml)
BUILD_NAME := $(word 1,$(subst +, ,$(PUBSPEC_VERSION)))
BUILD_NUMBER := $(word 2,$(subst +, ,$(PUBSPEC_VERSION)))
RELEASE_TAG := v$(BUILD_NAME)
RELEASE_TITLE := $(APP_NAME) $(BUILD_NAME)
RELEASE_NOTES_SOURCE := CHANGELOG.md
VOLUME_NAME := ScriptVault $(BUILD_NAME)
RELEASE_DIR := build/macos/Build/Products/Release
APP_PATH := $(RELEASE_DIR)/$(APP_NAME).app
DIST_DIR := build/dist
DMG_STAGING_DIR := $(DIST_DIR)/dmg
DMG_PATH := $(DIST_DIR)/$(APP_ID)-$(PUBSPEC_VERSION).dmg
LATEST_DMG_PATH := $(DIST_DIR)/$(APP_ID).dmg
BUMP_VERSION = ruby -e 'pubspec = "pubspec.yaml"; changelog = "CHANGELOG.md"; heading = 35.chr + " Changelog"; part = ARGV[0]; text = File.read(pubspec); new_version = nil; changed = text.sub(/^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*$$/) { major, minor, patch, build = [$$1, $$2, $$3, $$4].map(&:to_i); case part; when "major"; major += 1; minor = 0; patch = 0; when "minor"; minor += 1; patch = 0; else; patch += 1; end; build += 1; new_version = major.to_s + "." + minor.to_s + "." + patch.to_s + "+" + build.to_s; "version: " + new_version }; abort "No version line like x.y.z+build found in " + pubspec if new_version.nil? || changed == text; File.write(pubspec, changed); date = Time.now.strftime("%Y-%m-%d"); entry = 35.chr + 35.chr + " " + new_version + " - " + date + "\n\n- TODO: Add release notes.\n\n"; if File.exist?(changelog); existing = File.read(changelog); updated = existing.start_with?(heading) ? existing.sub(Regexp.new("\\A" + Regexp.escape(heading) + "\\s*\\n+"), heading + "\n\n" + entry) : heading + "\n\n" + entry + existing; else; updated = heading + "\n\n" + entry; end; File.write(changelog, updated); puts new_version'

release: dmg

release-version: release-preflight
	@test "$(PART)" = "major" -o "$(PART)" = "minor" -o "$(PART)" = "patch" || (echo 'Use PART=major, PART=minor, or PART=patch'; exit 1)
	$(MAKE) bump-$(PART)
	$(MAKE) release
	$(MAKE) release-info

release-info:
	@echo "Version: $(PUBSPEC_VERSION)"
	@echo "GitHub tag: $(RELEASE_TAG)"
	@echo "Release title: $(RELEASE_TITLE)"
	@echo "Release notes: $(RELEASE_NOTES_SOURCE)"
	@echo "DMG asset: $(DMG_PATH)"
	@echo "Latest DMG copy: $(LATEST_DMG_PATH)"
	@echo "Upload the DMG to: https://github.com/Anousack789/scriptvault/releases/new?tag=$(RELEASE_TAG)"

run:
	$(FLUTTER) run -d macos

release-preflight: check-cocoapods disable-swift-package-manager

check-cocoapods:
	@command -v pod >/dev/null || (echo 'CocoaPods is required. Install it or make sure /opt/homebrew/bin is on PATH.'; exit 1)

disable-swift-package-manager:
	$(FLUTTER) config --no-enable-swift-package-manager

dmg: release-preflight build-macos verify-release
	rm -rf "$(DMG_STAGING_DIR)" "$(DMG_PATH)" "$(LATEST_DMG_PATH)"
	mkdir -p "$(DMG_STAGING_DIR)" "$(DIST_DIR)"
	cp -R "$(APP_PATH)" "$(DMG_STAGING_DIR)/"
	ln -s /Applications "$(DMG_STAGING_DIR)/Applications"
	hdiutil create \
		-volname "$(VOLUME_NAME)" \
		-srcfolder "$(DMG_STAGING_DIR)" \
		-ov \
		-format UDZO \
		"$(DMG_PATH)"
	cp "$(DMG_PATH)" "$(LATEST_DMG_PATH)"
	@echo "Created $(DMG_PATH)"
	@echo "Updated $(LATEST_DMG_PATH)"

build-macos:
	$(FLUTTER) build macos --build-name "$(BUILD_NAME)" --build-number "$(BUILD_NUMBER)"

verify-release:
	@test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(APP_PATH)/Contents/Info.plist")" = "$(BUILD_NAME)"
	@test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(APP_PATH)/Contents/Info.plist")" = "$(BUILD_NUMBER)"

clean-dmg:
	rm -rf "$(DMG_STAGING_DIR)" "$(DMG_PATH)" "$(LATEST_DMG_PATH)"

version:
	@sed -n 's/^version: //p' pubspec.yaml

bump-version: bump-patch

bump-major:
	@$(BUMP_VERSION) major

bump-minor:
	@$(BUMP_VERSION) minor

bump-patch:
	@$(BUMP_VERSION) patch

version-control:
	git status --short
	git branch --show-current
	git log --oneline -5

vc: version-control
