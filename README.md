# Buds web

First read-only web version for **OnePlus Buds 4**, tested with firmware **138.138.105**, macOS and Google Chrome.

Run `npm start`, then open **http://127.0.0.1:8974/** in normal Chrome. Keep your earbuds connected in macOS and click **Connect earbuds**. A previously granted matching port can be reused; otherwise select your earbuds in the browser chooser. Use **Refresh state** to reread settings and **Disconnect** to close the control connection.

The page reads battery, wearing status, firmware, noise mode, EQ, gesture/call mappings, feature switches, connected devices, audio codec, BassWave and prompt volume. Battery, wearing and noise events update live. Missing case battery stays unknown; values retained after disconnect are marked as last reads.

Setting changes, sounds/tests, resets, firmware updates and cloud features are not enabled. The encoder permits only specific read queries and a temporary event subscription. This is the first feature slice, not complete HeyMelody parity.

The browser communicates directly through Web Serial RFCOMM. The Python server serves local files and receives optional diagnostic logs; it is not a Bluetooth bridge. Main dashboard data remains in browser memory. `/validation.html` is a separate diagnostic page which saves read-only validation logs locally.

There are no npm dependencies. Serving requires Python 3; tests require a recent Node.js with its built-in test runner. Run `npm test`.

The protocol core is in `web/protocol.js`, connection lifecycle in `web/device.js`, and UI in `web/app.js`. Research, attribution, captured evidence, remaining unknowns and the implementation roadmap are in [docs/heymelody](docs/heymelody/README.md). [Feature validation](docs/heymelody/feature-validation.md) describes the verified hardware behavior and first build.
