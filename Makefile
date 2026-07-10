# Use /Users/$(USER) (no spaces) for paths that launchd and exec() must resolve.
# $HOME may point to an external volume with spaces in the path.
# The CLI is just invoked interactively (by Keyboard Maestro etc.), so it
# belongs on the user's actual $HOME/.local/bin — the same place their shell
# PATH points at — not the SYS_HOME used for launchd-adjacent paths.
SYS_HOME      = /Users/$(USER)
PREFIX        = $(HOME)/.local/bin
LAUNCH_AGENTS = $(SYS_HOME)/Library/LaunchAgents
PLIST         = com.user.ddc-volume.plist
CONFIG_DIR    = $(HOME)/.config/ddc-volume

APP_NAME         = DDC Volume.app
APP_BUILD        = .build/app/$(APP_NAME)
APPLICATIONS_DIR = /Applications

DAEMON_BIN    = .build/release/DDCVolumeDaemon
CLI_BIN       = .build/release/DDCVolumeCLI

.PHONY: build test app install uninstall restart clean

build:
	swift build -c release

test:
	swift test

# Assemble the menu bar app into a real .app bundle so it can register itself
# as a login item via SMAppService (which requires a bundled main executable).
app: build
	rm -rf ".build/app"
	mkdir -p "$(APP_BUILD)/Contents/MacOS" "$(APP_BUILD)/Contents/Resources"
	install -m 755 "$(DAEMON_BIN)" "$(APP_BUILD)/Contents/MacOS/DDCVolumeDaemon"
	cp Info.plist.template "$(APP_BUILD)/Contents/Info.plist"
	codesign --force --deep --sign - "$(APP_BUILD)"

install: app
	mkdir -p "$(PREFIX)"
	install -m 755 "$(CLI_BIN)" "$(PREFIX)/ddc-volume"
	mkdir -p "$(CONFIG_DIR)"
	@if [ ! -f "$(CONFIG_DIR)/config.json" ]; then \
		echo "Writing example config to $(CONFIG_DIR)/config.json"; \
		printf '{\n  "monitorId": "REPLACE-WITH-YOUR-MONITOR-UUID",\n  "m1ddcPath": "/opt/homebrew/bin/m1ddc",\n  "minIntervalMs": 500,\n  "readVolumeOnStartup": true,\n  "defaultVolume": 60\n}\n' > "$(CONFIG_DIR)/config.json"; \
		echo "Edit $(CONFIG_DIR)/config.json and set your monitor UUID (run: m1ddc display list)"; \
	fi
	@echo "Migrating away from the legacy LaunchAgent, if present..."
	-launchctl bootout gui/$$(id -u) "$(LAUNCH_AGENTS)/$(PLIST)" 2>/dev/null || true
	rm -f "$(LAUNCH_AGENTS)/$(PLIST)"
	rm -f "$(PREFIX)/ddc-volume-daemon"
	-pkill -x DDCVolumeDaemon 2>/dev/null || true
	rm -rf "$(APPLICATIONS_DIR)/$(APP_NAME)"
	cp -R "$(APP_BUILD)" "$(APPLICATIONS_DIR)/"
	open -a "$(APPLICATIONS_DIR)/$(APP_NAME)"
	@echo "Installed to $(APPLICATIONS_DIR)/$(APP_NAME) and started."
	@echo "It registers itself to start at login on first launch (toggle any time from its menu, or in System Settings > General > Login Items)."

uninstall:
	-pkill -x DDCVolumeDaemon 2>/dev/null
	rm -rf "$(APPLICATIONS_DIR)/$(APP_NAME)"
	rm -f "$(PREFIX)/ddc-volume"
	-launchctl bootout gui/$$(id -u) "$(LAUNCH_AGENTS)/$(PLIST)" 2>/dev/null || true
	rm -f "$(LAUNCH_AGENTS)/$(PLIST)"
	@echo "Uninstalled. Config preserved at $(CONFIG_DIR)/"
	@echo "If 'DDC Volume' still appears in System Settings > General > Login Items, remove it there (it clears itself once the app is gone, but not always immediately)."

restart:
	-pkill -x DDCVolumeDaemon 2>/dev/null
	sleep 0.5
	open -a "$(APPLICATIONS_DIR)/$(APP_NAME)"

clean:
	swift package clean
	rm -rf .build/app
