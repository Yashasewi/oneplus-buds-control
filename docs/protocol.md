# OnePlus Buds 4 control link

OpenBuds talks to **OnePlus Buds 4** only, model `065414`, exercised on firmware **138.138.105**. The Mac app opens the earbuds' classic Bluetooth RFCOMM service. The web app uses Chrome's Web Serial API on that same service, after macOS has already paired the earbuds.

Service UUID: `0000079A-D102-11E1-9B23-00025B00A5A5`.

A frame is `AA`, a LEB128 length, `00 00`, the command as a little-endian `u16`, a sequence byte from 1 to 254, a little-endian payload length, then the payload. Replies set the high bit of the command (`command | 0x8000`). The earbuds acknowledge a write with status `00`. OpenBuds then reads the setting back. An acknowledgement by itself is not treated as success.

The two implementations are [native/Sources/BudsKit](../native/Sources/BudsKit) and [app/src/lib/protocol.ts](../app/src/lib/protocol.ts). Both refuse commands this project does not implement, including firmware updates, resets, pairing, ear scans, and cloud features.

The command bitmap in those files comes from [QuickBuds](https://github.com/spizganed/QuickBuds) (`desktop/src/protocol.rs`, `BIT_COMMANDS`), which is GPL-3.0-or-later. That is why OpenBuds is GPL-3.0-or-later.
