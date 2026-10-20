# OnePlus Buds control

Controllers for **OnePlus Buds 4**, tested with firmware **138.138.105** on macOS. There are two: a native Mac menu-bar app (`native/`) and a web app for Google Chrome (`app/`). Both talk to the earbuds directly over Bluetooth RFCOMM; there is no server.

## Mac menu-bar app

A menu-bar panel in the macOS Liquid Glass style: battery for both earbuds and the case, noise control, the Mac's volume, and pages for Sound, Controls, Features and Tools. It also shows a card when the earbuds connect and notifies you at 20% and 10% battery.

### Install

You need macOS 26 or later and Xcode (from the App Store). The build script uses `/Applications/Xcode.app` by itself; you do not need to run `xcode-select`.

```sh
git clone https://github.com/Yashasewi/oneplus-buds-control.git
cd oneplus-buds-control/native
./scripts/build-app.sh --install
```

This builds a release, signs it for this Mac, copies it to `/Applications/BudsBar.app` and opens it. The earbuds icon appears in the menu bar.

1. When macOS asks for Bluetooth access, click **Allow**. Without it the app cannot reach the earbuds.
2. Connect your earbuds to the Mac in Bluetooth settings as usual. The app connects to them by itself.
3. To start it with your Mac, open the panel, then **Features**, and turn on **Open at login**.

Quit the HeyMelody app or any Chrome tab using the web app first: only one app can hold the earbuds' control link at a time.

To update, pull and run `./scripts/build-app.sh --install` again. To uninstall, quit it from the panel and delete `/Applications/BudsBar.app`.

`./scripts/build-app.sh` without `--install` builds and opens a copy from `native/.build/` instead. The app must run as an app bundle: macOS does not open Bluetooth RFCOMM channels for bare command-line binaries.

The protocol is in `native/Sources/BudsKit/` (`Protocol.swift`, `Settings.swift`, `Session.swift`, `Link.swift`) and the interface in `native/Sources/BudsBar/`.

## Web app (Chrome)

The app is in `app/` (React, TypeScript, Tailwind, built with Vite+). Run `pnpm install` once, then `pnpm exec vp dev` inside `app/`, and open **http://localhost:5173/** in normal Chrome. Chrome remembers the earbuds per address, so always use this one (not `127.0.0.1`). Keep your earbuds connected in macOS and click **Connect earbuds**, then choose them in the browser chooser. After the first time, the page connects by itself when it opens or when the earbuds come back, unless you pressed **Disconnect**.

## What both apps do

They read battery, wearing status, firmware, noise mode, EQ, gesture and call mappings, feature switches, connected devices, audio codec, BassWave and prompt volume. Battery, wearing, noise, EQ and game-mode changes arrive live.

Settings can be changed: noise mode and ANC level, the touch-and-hold noise cycle, EQ presets and custom presets, BassWave, wear detection, game mode, smart volume, Golden Sound, Hi-Res, 3D Audio, gestures and call controls, dual connection and prompt volume. Every change needs the earbuds' acknowledgement and a matching read-back. Tools: find my earbuds, fit test and the Golden Sound hearing test. Hi-Res needs LHDC, which macOS does not support, so it is only available from devices that connect with LHDC.

Firmware updates, resets, pairing, ear scans, cloud features, codec selection and commands these earbuds do not advertise (tap sensitivity, head gestures, device manager, personalised ANC) are rejected by the encoder's allowlist. Music volume belongs to the playing device, not the earbuds' protocol, so the Mac app controls the Mac's output volume instead.

## History and research

The first, plain-JavaScript dashboard (`web/`, served by `serve_web.py` on port 8974) was removed after commit `212478a`. To look at it again without touching your branch: `git worktree add ../buds-old-dashboard 212478a`, then `npm start` in that folder.

The web protocol is in `app/src/lib/protocol.ts` and the connection in `app/src/lib/session.ts`. Research, attribution, captured evidence and remaining unknowns are in [docs/heymelody](docs/heymelody/README.md); the native app plan is in [docs/native-and-web-plan.md](docs/native-and-web-plan.md).
