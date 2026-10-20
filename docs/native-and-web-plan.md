# Plan: native menu-bar app and Vite+ web app

Two clients for OnePlus Buds 4 (`065414`, firmware 138.138.105), both built on the protocol already proven in Chrome (`app/src/lib/protocol.ts`, `app/src/lib/session.ts`): every setting change is acknowledged and read back, and live battery, wearing and noise events arrive.

1. **Native macOS menu-bar app** (Swift, SwiftUI): an AirPods-style top-bar control.
2. **Web app** moved to Vite+, React, TypeScript and Tailwind, keeping today's behaviour.

## What stays the same in both

The protocol rules do not change: the command allowlist, Buds 4 SET versus report noise tables, whole-table gesture writes, preset ids re-read after create/delete, Hi-Res link restart, 3D Audio/Hi-Res exclusivity, case battery only with the lid open, and "acknowledged is not verified". [QuickBuds PROTOCOL.md](heymelody/evidence/quickbuds/docs/PROTOCOL.md) and [unknowns](heymelody/unknowns.md) remain the references.

To keep the two implementations in agreement without sharing code across languages, export the known-good frames (the hardware captures in `docs/heymelody/evidence/` plus the QuickBuds write captures) as one JSON file of `{command, payload, bytes}` examples. Each client's encoder must reproduce them.

## Track 1: native menu-bar app

### Technology

| Part | Choice | Why |
|---|---|---|
| UI | SwiftUI `MenuBarExtra` with `.window` style, macOS 13+ | Native top-bar panel like the AirPods menu; rich layout, not just a menu list. |
| Bluetooth | `IOBluetooth` RFCOMM | The same classic-Bluetooth service Chrome reaches through Web Serial (`0000079A-D102-11E1-9B23-00025B00A5A5`). |
| Protocol | Swift package `BudsKit`: framer, encoder/allowlist, decoders, `BudsSession` actor | A direct port of `protocol.ts`/`session.ts`; testable without the UI. |
| Music volume | CoreAudio (`kAudioHardwareServiceDeviceProperty_VirtualMainVolume` on the buds' output device) | The earbuds' protocol has no media-volume command; the Mac owns it. Browsers can't set it. |
| Login item | `SMAppService.mainApp` | Starts at login, no helper app. |
| Shortcuts | `KeyboardShortcuts`-style global hotkey (or `NSEvent` monitor) | Cycle noise mode without opening the panel. |
| Distribution | Ad-hoc signed for personal use; Developer ID and notarization only if shared | Avoids App Store sandbox limits on Bluetooth while personal. |

Info.plist needs `NSBluetoothAlwaysUsageDescription`. If sandboxed, add the `com.apple.security.device.bluetooth` entitlement.

### Connection flow

1. Find the paired device: `IOBluetoothDevice.pairedDevices()`, then choose the one whose SDP record lists the service UUID above. Confirm model `065414` with `0x0103`, as today.
2. Read the RFCOMM channel id from that SDP record (`IOBluetoothSDPServiceRecord.getRFCOMMChannelID`). Never hardcode it.
3. `openRFCOMMChannelAsync`, receive bytes in `rfcommChannelData`, feed the framer, then write frames with `writeSync`.
4. Register `IOBluetoothDevice.register(forConnectNotifications:)` so the app connects automatically when the buds connect to the Mac, plus a per-device disconnect notification. Lid close drops the link; the app waits for the next connect instead of retrying.
5. Answer the buds' `0x0500` time request (`00 <unix seconds u32 LE>`), as HeyMelody does. Buds 4 tolerates silence, but a long-lived client should reply.
6. Run the same connect sequence: capability bitmap, model, full refresh, then subscribe to events 1, 2, 3, 4 and 8.

### UI

- **Menu-bar icon:** buds glyph plus the lower of the two bud levels; a charging bolt while charging. Hidden levels show as no number, never a stale one without marking.
- **Panel, top:** left, right and case battery rings (case only when reported), connection state.
- **Panel, volume:** a music-volume slider for the buds' output device, kept in sync when volume changes elsewhere.
- **Panel, controls:** noise mode segmented control (Off, Noise cancelling, Transparency, Adaptive) with ANC level beneath; EQ preset picker; BassWave; quick toggles (game mode, 3D Audio, wear detection).
- **Settings window** (opened from the panel): gestures per ear and call controls, touch-and-hold noise cycle, custom EQ editor, dual connection, Hi-Res, prompt volume, Golden Sound, fit test, find my earbuds, hearing test.
- **On connect:** a small floating card near the menu bar with the battery levels, dismissing itself after a few seconds. This approximates the AirPods pop-up; the real case-open animation is a private Apple feature and is not possible.
- **Notifications:** low battery for each bud and the case.

### Native-only features to add

Start at login, auto-connect, a global shortcut for the noise cycle, low-battery notifications and optional "pause/resume when the buds come out" using media keys. HeyMelody's smart auto-pause is the phone app's own logic, not firmware.

### Milestones

1. **Link proof:** a command-line Swift tool opens RFCOMM, sends `0x0100`/`0x0103`, prints battery and receives a wearing push. This answers the main native unknown before any UI work.
   Done (`native/`, run with `native/scripts/run-probe.sh`). Finding: macOS refuses every RFCOMM channel (`openRFCOMMChannelSync` returns `0xe00002bc`, the async open never completes) when the tool runs as a bare binary from a terminal, even with Bluetooth permission granted. The same binary inside an ad-hoc-signed `.app` launched through LaunchServices connects at once, reads identity, firmware, battery, wearing and noise, and receives live events. The menu-bar app is a bundle anyway; tools must be wrapped the same way. The control service is SDP "enco link" on channel 15 for this pair.
2. **BudsKit:** port the encoder, framer, decoders and session; reproduce the frame examples.
3. **Menu-bar MVP:** icon with battery, panel with noise mode and EQ preset, auto-connect.
4. **Full parity with the web app:** settings window with every current control and tool.
5. **Native extras:** login item, shortcut, notifications, on-connect card.

## Track 2: web app on Vite+

1. Scaffold with Vite+ (`vp`) using React and TypeScript, plus Tailwind. Keep the dev server on a fixed origin (`localhost:5173`, strict port), since Chrome's granted serial port is tied to it.
2. Move `protocol.js` and `device.js` to `src/lib/` as TypeScript without changing behaviour. Type the state (`DeviceState`) and command builders.
3. Expose the session through a `useBuds()` hook with an external store (`useSyncExternalStore`) that publishes immutable snapshots.
4. Rebuild the UI as components with a new design: a fixed "now" panel (sound field, noise control, battery) and a grouped settings list (Sound, Touch controls, Features, Connections, Tools, About). Each row shows its own pending, confirmed or error state.
5. Connect automatically to the already-granted port on load and when the buds come back; re-read settings when the tab regains focus.

Status: done in `app/` (`vp dev` serves it on `localhost:5173`); the old `web/` dashboard was removed after commit `212478a`.

The web app stays Chrome-only (Web Serial over Bluetooth). Cursor's and other Electron browsers expose the API but do not offer a device chooser.

## Out of scope for both

| Feature | Why |
|---|---|
| Cloud/account features (AI translation, themes, sign-in) | Skipped by decision. |
| Ear scan for Golden Sound | Skipped by decision; the hearing test makes the Golden Sound profile without it. |
| Firmware updates (OTA) | Transfer, verification, resume and recovery are untraced ([U13](heymelody/unknowns.md)); a mistake can brick the buds. |
| Features the buds do not advertise | Tap sensitivity, head gestures, device manager and personalised ANC are absent from the capability bitmap. |

## Open questions

- Can the native app and Chrome, or HeyMelody on a phone, hold the RFCOMM link at the same time? Expect one client per host at a time; milestone 1 should check.
- Behaviour across Mac sleep and wake, and when the buds switch to the other device in dual connection.
- Whether macOS asks for Bluetooth permission for an ad-hoc signed app on each rebuild.
