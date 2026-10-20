# Buds web

Web controller for **OnePlus Buds 4**, tested with firmware **138.138.105**, macOS and Google Chrome.

The app is in `app/` (React, TypeScript, Tailwind, built with Vite+). Run `pnpm install` once, then `pnpm exec vp dev` inside `app/`, and open **http://localhost:5173/** in normal Chrome. Chrome remembers the earbuds per address, so always use this one (not `127.0.0.1`). Keep your earbuds connected in macOS and click **Connect earbuds**, then choose them in the browser chooser. After the first time, the page connects by itself when it opens or when the earbuds come back, unless you pressed **Disconnect**.

The page reads battery, wearing status, firmware, noise mode, EQ, gesture and call mappings, feature switches, connected devices, audio codec, BassWave and prompt volume. Battery, wearing, noise, EQ and game-mode changes arrive live; everything else is read again when you come back to the tab. Values kept after a disconnect are shown as last reads.

Settings can be changed: noise mode and ANC level, the touch-and-hold noise cycle, EQ presets and custom presets, BassWave, wear detection, game mode, smart volume, Golden Sound, Hi-Res, 3D Audio, gestures and call controls, dual connection and prompt volume. Every change needs the earbuds' acknowledgement and a matching read-back. Tools: find my earbuds, fit test and the Golden Sound hearing test. Hi-Res needs LHDC, which macOS does not support, so it is only available from devices that connect with LHDC.

Firmware updates, resets, pairing, ear scans, cloud features, codec selection and commands these earbuds do not advertise (tap sensitivity, head gestures, device manager, personalised ANC) are rejected by the encoder's allowlist. Music volume belongs to the playing device, not the earbuds' control protocol; it is planned for the native Mac app.

The first, plain-JavaScript dashboard (`web/`, served by `serve_web.py` on port 8974) was removed after commit `212478a`. To look at it again without touching your branch: `git worktree add ../buds-old-dashboard 212478a`, then `npm start` in that folder.

The browser talks to the earbuds directly over Web Serial (Bluetooth RFCOMM); there is no server-side bridge. The protocol is in `app/src/lib/protocol.ts` and the connection in `app/src/lib/session.ts`. Research, attribution, captured evidence and remaining unknowns are in [docs/heymelody](docs/heymelody/README.md); the native app plan is in [docs/native-and-web-plan.md](docs/native-and-web-plan.md).
