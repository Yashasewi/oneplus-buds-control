# Buds web

Web controller for **OnePlus Buds 4**, tested with firmware **138.138.105**, macOS and Google Chrome.

The new app (React, TypeScript, Tailwind, built with Vite+) is in `app/`: run `pnpm install` once, then `pnpm exec vp dev` inside `app/`. The older dashboard in `web/` stays as a fallback and runs with `npm start`. Both use the same address, so run only one at a time.

Open **http://127.0.0.1:8974/** in normal Chrome. Keep your earbuds connected in macOS and click **Connect earbuds**. A previously granted matching port can be reused; otherwise select your earbuds in the browser chooser.

The page reads battery, wearing status, firmware, noise mode, EQ, gesture/call mappings, feature switches, connected devices, audio codec, BassWave and prompt volume. Battery, wearing and noise events update live. Missing case battery stays unknown; values retained after disconnect are marked as last reads.

Settings can be changed: noise mode and ANC level, the touch-and-hold noise cycle, EQ presets and custom presets, BassWave, wear detection, game mode, Golden Sound, Hi-Res, OnePlus 3D Audio, gestures and call controls, dual connection and prompt volume. Every change needs the earbuds' acknowledgement and a matching read-back; an acknowledgement alone is reported as unverified. Tools: find my earbuds, fit test and the Golden Sound hearing test. Hi-Res changes restart the earbuds' link and the page reconnects. Write payloads come from QuickBuds' Buds 4 captures and HeyMelody's Buds 4 menus; most are not yet confirmed on this pair.

Firmware updates, resets, pairing, ear scans, codec selection and commands these earbuds do not advertise (tap sensitivity, head gestures, device manager, personalised ANC) are rejected by the encoder's allowlist.

The browser communicates directly through Web Serial RFCOMM. The Python server serves local files and receives optional diagnostic logs; it is not a Bluetooth bridge. Main dashboard data remains in browser memory. `/validation.html` is a separate diagnostic page which saves read-only validation logs locally.

There are no npm dependencies. Serving requires Python 3; tests require a recent Node.js with its built-in test runner. Run `npm test`.

The protocol core is in `web/protocol.js`, connection lifecycle in `web/device.js`, and UI in `web/app.js`. Research, attribution, captured evidence, remaining unknowns and the implementation roadmap are in [docs/heymelody](docs/heymelody/README.md). [Feature validation](docs/heymelody/feature-validation.md) describes the verified hardware behavior and first build.
