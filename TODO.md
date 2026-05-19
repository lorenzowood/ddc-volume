# TODO / Future directions

## Settings dialog

A click-through settings UI in the menu bar dropdown rather than hand-editing `config.json`:
- Monitor selector (already in the menu, but switching doesn't persist)
- Rate limit slider
- Default volume
- Toggle for read-on-startup

## Generalise to a pluggable volume control system

The current architecture (rate-limited in-memory state → command dispatch → physical control) is backend-agnostic. The DDC path is just one driver. Others worth adding:

### Backends to consider

- **DDC** (current) — external monitors via m1ddc; see also [AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC), a Swift library by the same author that speaks DDC natively without requiring m1ddc to be installed — refactoring the DDC backend to link against this library directly would remove the external tool dependency
- **macOS system audio** — `osascript`/CoreAudio; would let this tool replace the system Sound menu item entirely
- **Behringer (and other USB mixers)** — MIDI sysex or HID; the mixer presents as a USB device and its main output level can be set programmatically
- **HomeAssistant** — REST/WebSocket API to control a media player or number entity; useful where the audio zone is separate from the display (e.g. a kitchen screen that sometimes routes audio to a whole-room system)

### Replace the system Sound control

Having two volume indicators (system and this one) is confusing. If this tool grew to control system audio as well, it could subsume the system Sound menu item. Would need:
- Listing all output devices (CoreAudio `AudioObjectGetPropertyData`)
- Per-device volume, mute, and selection
- Matching the system Sound panel's appearance closely enough that users don't miss it

### Context-aware routing

Some setups need the active backend to change depending on what's happening:
- Laptop docked → DDC monitor speakers
- Same machine casting to a TV → HomeAssistant zone
- Kitchen computer → local monitor unless the big screen is active, in which case also (or instead) control that zone

This implies a notion of *routing rules* — probably a simple priority list of backends with an optional activation condition (e.g. a HomeAssistant entity state, or a specific display being connected).

### Concrete next step

Define a `VolumeBackend` protocol:

```swift
protocol VolumeBackend {
    var name: String { get }
    func getVolume() throws -> Int        // 0–100
    func setVolume(_ volume: Int) throws
    func listTargets() throws -> [BackendTarget]
}
```

Refactor `MonitorController` to conform to it. Add `SystemAudioBackend` next. The daemon holds an ordered list of active backends; the UI exposes them all.
