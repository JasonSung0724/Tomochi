# Same location the installer/Sparkle use — two coexisting copies would fight.
APP_DIR ?= /Applications

.PHONY: build run install clean

build:
	@bash scripts/build.sh release

install: build
	@mkdir -p "$(APP_DIR)"
	@rm -rf "$(APP_DIR)/Tomochi.app"
	@cp -R Tomochi.app "$(APP_DIR)/Tomochi.app"
	@rm -rf Tomochi.app
	@echo "✓ Installed to $(APP_DIR)/Tomochi.app"

run: install
	@open "$(APP_DIR)/Tomochi.app"

dev:
	@swift build && .build/debug/Tomochi

clean:
	@rm -rf .build dist Tomochi.app
	@echo "✓ Cleaned"
