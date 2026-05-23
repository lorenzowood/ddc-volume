# Use /Users/$(USER) (no spaces) for paths that launchd and exec() must resolve.
# $HOME may point to an external volume with spaces in the path.
SYS_HOME      = /Users/$(USER)
PREFIX        = $(SYS_HOME)/.local/bin
LAUNCH_AGENTS = $(SYS_HOME)/Library/LaunchAgents
PLIST         = com.user.ddc-volume.plist
CONFIG_DIR    = $(HOME)/.config/ddc-volume

DAEMON_BIN    = .build/release/DDCVolumeDaemon
CLI_BIN       = .build/release/DDCVolumeCLI

.PHONY: build test install uninstall restart clean

build:
	swift build -c release

test:
	swift test

install: build
	mkdir -p "$(PREFIX)"
	install -m 755 "$(DAEMON_BIN)" "$(PREFIX)/ddc-volume-daemon"
	install -m 755 "$(CLI_BIN)"    "$(PREFIX)/ddc-volume"
	mkdir -p "$(CONFIG_DIR)"
	@if [ ! -f "$(CONFIG_DIR)/config.json" ]; then \
		echo "Writing example config to $(CONFIG_DIR)/config.json"; \
		printf '{\n  "monitorId": "REPLACE-WITH-YOUR-MONITOR-UUID",\n  "m1ddcPath": "/opt/homebrew/bin/m1ddc",\n  "minIntervalMs": 500,\n  "readVolumeOnStartup": true,\n  "defaultVolume": 60\n}\n' > "$(CONFIG_DIR)/config.json"; \
		echo "Edit $(CONFIG_DIR)/config.json and set your monitor UUID (run: m1ddc display list)"; \
	fi
	mkdir -p "$(LAUNCH_AGENTS)"
	sed 's|__DAEMON_PATH__|$(PREFIX)/ddc-volume-daemon|g' "$(PLIST).template" \
		> "$(LAUNCH_AGENTS)/$(PLIST)"
	launchctl bootout gui/$$(id -u) "$(LAUNCH_AGENTS)/$(PLIST)" 2>/dev/null || true
	launchctl bootstrap gui/$$(id -u) "$(LAUNCH_AGENTS)/$(PLIST)"
	@echo "Installed and started."

uninstall:
	-launchctl bootout gui/$$(id -u) "$(LAUNCH_AGENTS)/$(PLIST)" 2>/dev/null
	-rm -f "$(PREFIX)/ddc-volume-daemon"
	-rm -f "$(PREFIX)/ddc-volume"
	-rm -f "$(LAUNCH_AGENTS)/$(PLIST)"
	@echo "Uninstalled. Config preserved at $(CONFIG_DIR)/"

restart:
	launchctl bootout   gui/$$(id -u) "$(LAUNCH_AGENTS)/$(PLIST)"
	launchctl bootstrap gui/$$(id -u) "$(LAUNCH_AGENTS)/$(PLIST)"

clean:
	swift package clean
