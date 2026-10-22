# OnePlus Buds 4 control link

OpenBuds talks to **OnePlus Buds 4** only, model `065414`, exercised on firmware **138.138.105**. The Mac app opens the earbuds' classic Bluetooth RFCOMM service. The web app uses Chrome's Web Serial API on that same service, after macOS has already paired the earbuds.

Service UUID: `0000079A-D102-11E1-9B23-00025B00A5A5`.

The same frames also travel over GATT, which is how HeyMelody stays connected while OpenBuds holds the RFCOMM channel. HeyMelody's device record marks the Buds 4 `gattV2`: it attaches GATT to the classic connection macOS already has open, and it does not start a separate Bluetooth Low Energy scan. bluetoothd reports that session as `transport: classic`. The buds keep both links and push a change to each, so noise control, battery, and the equalizer show up in both apps. The classic channel still allows only one program per computer. Two GATT clients on that one link are untested.

HeyMelody sorts the characteristics by UUID when they are discovered (`PeripheralDataRW.swift` in the 2026-10-12 decompile of HeyMelody `0fb1d5d2…`):

| UUID | Use |
|---|---|
| `0200079A-D102-11E1-9B23-00025B00A5A5` | Notifications. Command replies arrive here. |
| `0200079F-D102-11E1-9B24-00025B00A5A5` | Notifications for the AI feature only. |
| `0100079A-D102-11E1-9B23-00025B00A5A5` | Writes. Commands are sent here. Notifications stay off. |
| `0100079C-D102-11E1-9B23-00025B00A5A5` | Cross-transport pairing (CTKD). Not a control channel. |

The lists also contain the short forms `00000002-…`, `00000001-…`, and `00000004-…` for older models. A GATT send does not cut the bytes at the `writeValue` call. `otaFrameRequest(command:for:timeout:onSuccess:onError:)` in `BTManager.swift` (Ghidra `FUN_100b2af94`, evidence `ev_5b8b84407986fdb57df3329e9d169988f5ab443440f1ad63a693f2e519351070`) walks a sequence of `Data` values and writes each one whole. The write type is `1`, `CBCharacteristicWriteWithoutResponse` (`FUN_100259f60` returns that constant). The normal sender `request(command:for:timeout:onSuccess:onError:)` uses the same write stub. `PeripheralMTUDecoder` is a response decoder with one field, `contentData`. It does not split the outgoing bytes. The number of bytes per `Data` value is still unresolved.

A frame is `AA`, a LEB128 length, `00 00`, the command as a little-endian `u16`, a sequence byte from 1 to 254, a little-endian payload length, then the payload. Replies set the high bit of the command (`command | 0x8000`). The earbuds acknowledge a write with status `00`. OpenBuds then reads the setting back. An acknowledgement by itself is not treated as success.

The two implementations are [native/Sources/BudsKit](../native/Sources/BudsKit) and [app/src/lib/protocol.ts](../app/src/lib/protocol.ts). Both refuse commands this project does not implement, including firmware updates, resets, pairing, ear scans, and cloud features.

The command bitmap in those files comes from [QuickBuds](https://github.com/spizganed/QuickBuds) (`desktop/src/protocol.rs`, `BIT_COMMANDS`), which is GPL-3.0-or-later. That is why OpenBuds is GPL-3.0-or-later.
