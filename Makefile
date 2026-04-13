APP_NAME = MemoDismiss
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
SOURCES = Sources/MemoDismiss/main.swift \
          Sources/MemoDismiss/AppDelegate.swift \
          Sources/MemoDismiss/MemoWatcher.swift

SWIFTC = swiftc
SWIFTFLAGS = -O -target arm64-apple-macosx12.0 -target x86_64-apple-macosx12.0

.PHONY: build install uninstall clean

build: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) Resources/Info.plist
	@echo "Building $(APP_NAME)..."
	@mkdir -p $(MACOS)
	@# Build arm64
	swiftc -O -target arm64-apple-macosx12.0 \
		$(SOURCES) -o $(BUILD_DIR)/$(APP_NAME)-arm64
	@# Build x86_64
	swiftc -O -target x86_64-apple-macosx12.0 \
		$(SOURCES) -o $(BUILD_DIR)/$(APP_NAME)-x86_64
	@# Create universal binary
	lipo -create -output $(MACOS)/$(APP_NAME) \
		$(BUILD_DIR)/$(APP_NAME)-arm64 \
		$(BUILD_DIR)/$(APP_NAME)-x86_64
	@cp Resources/Info.plist $(CONTENTS)/Info.plist
	@rm -f $(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64
	@codesign --force --sign - $(APP_BUNDLE)
	@echo "Built: $(APP_BUNDLE)"

install: build
	@echo "Installing to /Applications..."
	@cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed: /Applications/$(APP_NAME).app"
	@echo "You can now open it from /Applications or enable 'Launch at Login' from the menu bar."

uninstall:
	@echo "Uninstalling..."
	@rm -rf /Applications/$(APP_NAME).app
	@rm -f ~/Library/LaunchAgents/com.github.MemoDismiss.plist
	@echo "Uninstalled."

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned."
