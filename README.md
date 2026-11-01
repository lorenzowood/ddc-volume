# ddc-volume

A macOS menu bar utility for controlling the built-in speaker volume of external monitors via DDC, with rate-limited command dispatch to handle fast input gracefully.

## The problem

DDC (Display Data Channel) lets you send commands to an external monitor over the cable — including volume control. The excellent [m1ddc](https://github.com/waydabber/m1ddc) utility makes this easy on Apple Silicon Macs.

The trouble is that DDC monitors don't cope well with rapid sequential commands. If you bind a keyboard knob to volume up/down and spin it quickly, the monitor can get confused: volume jumps to 100, drops to 0, or stops responding to small adjustments.

## How it works

`ddc-volume` separates *intent* from *execution*:

- A menu bar daemon maintains the **desired volume** in memory and accepts commands over a Unix socket.
- A rate-limiting timer (default: 500 ms) checks whether the desired volume differs from the last value sent to the monitor. If so, it issues a single `set volume <n>` command — regardless of how many knob clicks arrived in the meantime.
- CLI commands (`ddc-volume up 5`, etc.) just update the in-memory value and return immediately, so rapid input is absorbed cleanly.
- **Mute** is implemented by setting the monitor volume to 0 and restoring it on unmute, since DDC mute is not reliably supported across monitors.

The menu bar icon is a volume bar that reflects the desired volume instantly, giving visual feedback even before the monitor catches up.

### Staying in sync with the monitor

The monitor is the source of truth. If something else changes its volume (for example MonitorControl or the
keyboard's volume keys), the app notices: it re-reads the monitor before applying a change that is more than
5 seconds since the last read, and refreshes every 5 seconds while the screen is awake and nothing is pending (change or turn off in the menu under *Refresh from Monitor*). Pending knob steps are re-based onto the real level, so a click steps from where the monitor actually is, and an
outside change while muted unmutes the display.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 13 Ventura or later
- [m1ddc](https://github.com/waydabber/m1ddc) — install with Homebrew:

  ```sh
  brew install m1ddc
  ```

- A monitor that supports DDC volume control over USB-C / DisplayPort

## Installation

```sh
git clone https://github.com/lorenzowood/ddc-volume.git
cd ddc-volume
make install
```

`make install` builds the project, packages the menu bar app as `DDC Volume.app` in `/Applications`, installs the `ddc-volume` CLI to `~/.local/bin/`, and writes an example config file. The app registers itself to start at login the first time it launches — see [Menu bar](#menu-bar) below to toggle this, or check System Settings → General → Login Items, where it appears as "DDC Volume".

Make sure `~/.local/bin` is in your `PATH`:

```sh
# add to ~/.zshrc if needed
export PATH="$HOME/.local/bin:$PATH"
```

## Configuration

Edit `~/.config/ddc-volume/config.json`. An example is written on first install:

```json
{
  "monitorId": "REPLACE-WITH-YOUR-MONITOR-UUID",
  "m1ddcPath": "/opt/homebrew/bin/m1ddc",
  "minIntervalMs": 500,
  "readVolumeOnStartup": true,
  "defaultVolume": 60
}
```

Find your monitor's UUID:

```sh
m1ddc display list
```

After editing the config, restart the daemon:

```sh
make restart
```

| Key | Description |
|-----|-------------|
| `monitorId` | UUID from `m1ddc display list` |
| `m1ddcPath` | Path to the m1ddc binary |
| `minIntervalMs` | Minimum time between DDC commands (ms). 500 is a safe default; lower if your monitor is responsive |
| `readVolumeOnStartup` | Read the monitor's current volume on launch rather than setting `defaultVolume` |
| `defaultVolume` | Volume to use on startup if `readVolumeOnStartup` is false or fails |

## CLI

```sh
ddc-volume up <n>       # Increase volume by n
ddc-volume down <n>     # Decrease volume by n
ddc-volume set <n>      # Set volume to n (0–100)
ddc-volume get          # Print current volume and mute state
ddc-volume mute
ddc-volume unmute
ddc-volume togglemute
```

## Keyboard bindings

The intended use is a keyboard with assignable knobs. Assign:

- Clockwise click → shell command: `ddc-volume up 5`
- Anti-clockwise click → shell command: `ddc-volume down 5`

[Keyboard Maestro](https://www.keyboardmaestro.com/) works well for binding arbitrary keys to shell commands.

## Menu bar

Click the volume bar in the menu bar to open a dropdown with:

- A slider for direct volume adjustment, with a fixed speaker icon on the left that mirrors macOS's own system volume control: it shows 0–3 sound waves depending on level, and doubles as a mute button — click it (or run `ddc-volume mute`/`unmute`/`togglemute`) to mute, which shows an × next to the speaker and dims the slider without disabling it
- A monitor selector — click any listed monitor to switch control to it (session only; edit `config.json` to change the default)
- **Start at Login** — checkbox reflecting whether the app is registered to launch at login (backed by `SMAppService`, the same mechanism System Settings → General → Login Items uses); toggle it from either place
- **Quit**

## Troubleshooting

**Menu bar icon is gone after a reboot**

Check System Settings → General → Login Items for "DDC Volume" — if it's missing or shows an error, re-running `make install` is safe and idempotent:

```sh
make install
```

**Daemon is running but not responding**

```sh
make restart
```

There's no `/tmp/ddc-volume.log` anymore — the app logs via the unified logging system instead:

```sh
log stream --predicate 'process == "DDCVolumeDaemon"'
```

or open Console.app and filter on "DDCVolumeDaemon".

## Makefile targets

```sh
make build      # Build (debug)
make test       # Run tests
make install    # Build release, install DDC Volume.app and the CLI
make restart    # Restart the running app
make uninstall  # Remove the app and CLI (config preserved)
make clean      # Remove build artefacts
```

## Credits

This utility is built on top of [m1ddc](https://github.com/waydabber/m1ddc) by [waydabber](https://github.com/waydabber), which provides DDC control over USB-C/DisplayPort on Apple Silicon Macs. Without it, none of this would be possible.
