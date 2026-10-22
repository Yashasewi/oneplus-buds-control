# Prompt: Mac app control link over GATT

You are implementing the next OpenBuds transport. The channel-15 contention bug is already fixed on `dev` (pull request #17). Do not reopen it and do not treat this work as that bugfix. This work is the improvement: the Mac app talks GATT, the same way HeyMelody does, so it can stay connected while the website holds RFCOMM channel 15. A change made on either side shows up on the other because the buds push it to both links.

Work in `/Users/yash/Desktop/Personal/REA`. Branch off `origin/dev`. Open the pull request against `dev`.

## Outcome

The menu-bar app connects to OnePlus Buds 4 over GATT on the classic Bluetooth connection macOS already has open. It no longer opens RFCOMM channel 15 on the normal path. The website stays on Web Serial and is not modified. A short command (battery or model) round-trips on GATT. Frames use the codec already in `native/Sources/BudsKit/Protocol.swift`. A write longer than one without-response packet is reported and not silently sliced.

## Do not

- Do not move the website to Web Bluetooth. Chrome discovers advertisers and opens a Low Energy connection. HeyMelody does not. Its log says a `gattV2` device is not connected through a Bluetooth Low Energy scan. Web Serial stays the website transport.
- Do not open RFCOMM channel 15 when GATT is available. That channel allows one program per computer. Opening it steals the website.
- Do not add an automatic RFCOMM fallback. A failed GATT discovery shows an error and leaves channel 15 free.
- Do not invent a chunk size. `PeripheralMTUDecoder` is a reply decoder with one field, `contentData`. It does not split outgoing bytes. `maximumWriteValueLengthForType:` is not in the HeyMelody binary. The number of bytes per `Data` value is unknown.
- Do not subscribe to the AI notify characteristic.
- Do not touch `0100079C-…`. That is cross-transport pairing (CTKD), not control.
- Do not send firmware updates, resets, pairing, ear scans, or cloud commands. The existing command allow-list stays.
- Do not change frame bytes for the RFCOMM codec. GATT carries the same frames.

## Facts you must preserve

Binary: `/Applications/HeyMelody.app/Wrapper/HeyMelody.app/HeyMelody`, sha256 `0fb1d5d2824b5aee98b439844287fb3cd266fa3b417d7a799d91a1169bc9befc`. Buds 4 model `065414`, firmware exercised at `138.138.105`. The public write-up is `docs/protocol.md`. Addresses and evidence ids are in `docs/heymelody/evidence/kept-local/gatt-link.md`.

HeyMelody's Buds 4 record sets `gattV2` and `ctkd`. On 2026-10-22 21:45 bluetoothd attached `com.heytap.heymelodyI18n` with `transport: classic` while OpenBuds held RFCOMM channel `0xf`. Both stayed up. Characteristic writes continued after the RFCOMM channel connected. Noise control, battery, and the equalizer arrived on both apps. Gestures and some switches are not pushed; they update on the next read.

GATT characteristics, from `FUN_100c8204c` in the 2026-10-12 decompile (`PeripheralDataRW.swift`, `btManager(_:_:didDiscoverCharacteristicsFor:error:task:)`):

| UUID | Role |
|---|---|
| `0200079A-D102-11E1-9B23-00025B00A5A5` | Notify. Command replies. Turn notifications on. |
| `0200079F-D102-11E1-9B24-00025B00A5A5` | Notify, AI feature only. Leave it alone. |
| `0100079A-D102-11E1-9B23-00025B00A5A5` | Write. Commands. Notifications stay off. |
| `0100079C-D102-11E1-9B23-00025B00A5A5` | CTKD. Leave it alone. |

Short forms `00000001-0000-1000-8000-00805F9B34FB`, `00000002-…`, and `00000004-…` are for older models. Match the 128-bit ids above.

The RFCOMM service UUID `0000079A-D102-11E1-9B23-00025B00A5A5` is the classic service. It is not proven to be the GATT service UUID. Discover services on the connected peripheral and select characteristics by the ids in the table. Record the parent service UUID you actually find in `docs/protocol.md`.

Write type is `CBCharacteristicWriteWithoutResponse` (raw value `1`). `FUN_100259f60` returns that constant. Evidence for the sender is `ev_5b8b84407986fdb57df3329e9d169988f5ab443440f1ad63a693f2e519351070`: Ghidra `FUN_100b2af94`, source `BTManager.swift`, `otaFrameRequest(command:for:timeout:onSuccess:onError:)`. It iterates `Data` values, bridges each one to `NSData`, and writes it whole. `request(command:for:timeout:onSuccess:onError:)` uses the same write stub (`0x101418060`, selector `writeValue:forCharacteristic:type:` at `0x1014a3412`).

A frame is `AA`, a LEB128 length, `00 00`, the command as a little-endian `u16`, a sequence byte from 1 to 254, a little-endian payload length, then the payload. Replies set the high bit (`command | 0x8000`). `Framer` in `Protocol.swift` already accepts those bytes. Pass notification bytes to it in order. Do not strip or wrap them unless a live capture shows a prefix the RFCOMM path does not have. If the first battery reply does not parse, stop and record the raw bytes. Do not guess a header.

## Design

`BudsSession` in `native/Sources/BudsKit/Session.swift` owns the link, the sequence counter, request matching, and state. Keep that. Add a GATT link beside `RFCOMMLink` in `native/Sources/BudsKit/Link.swift` with the same surface the session needs: connect, write, close, `onData`, `onClose`.

`connect()` tries GATT only.

1. The buds are already paired and classic-connected (audio). `IOBluetooth` or `CBCentralManager.retrieveConnectedPeripherals` is how you see that. HeyMelody called `CBMsgIdConnectPeripheral` and the session came up with `transport: classic`. Do not scan. Do not call `scanForPeripherals`.
2. Connect the CoreBluetooth peripheral, discover services, then characteristics.
3. `setNotifyValue(true)` on `0200079A-…` only.
4. Wait until notifications are enabled, then run the existing handshake: `0x0100` capabilities, `0x0103` model, require model `065414`, then `refresh()` and event subscribe. Those commands already live in `BudsSession.connect()`.
5. Incoming notifications append to `Framer`. The session's existing `received` path handles frames.
6. Writes go to `0100079A-…` with `.withoutResponse`. If `canSendWriteWithoutResponse` is false, queue until `peripheralIsReady(toSendWriteWithoutResponse:)`. HeyMelody references that callback.
7. One queued write at a time, matching the session lock that already serializes commands.
8. If a single encoded frame is rejected by CoreBluetooth, or `canSendWriteWithoutResponse` stays false long enough to hit the existing command timeout, fail that command with a message that includes the frame length. Do not split it.
9. Disconnect, classic-audio drop, and the user power button close the GATT connection and cancel the queue. Reuse the current reconnect behavior that runs when the buds connect again, but connect GATT instead of RFCOMM.
10. The retry loop added for a busy channel 15 must not run against RFCOMM. GATT failure is a GATT error, not "another app holds channel 15".

`native/Package.swift` links `IOBluetooth`. Link `CoreBluetooth` as well. The app bundle already has `NSBluetoothAlwaysUsageDescription` in `native/scripts/package-app.sh`. Keep it. Add a peripheral-usage string only if the binary refuses to launch without one.

The website (`app/`) is out of scope. `docs/protocol.md` is in scope: say the Mac app's control link is GATT, the website's is still Web Serial on channel 15, and record the parent service UUID and any prefix you had to prove with a capture.

## Build order

1. GATT link type and UUID constants, with the write path refusing an empty packet and recording the byte count of each write.
2. Session uses that link from `connect()`. RFCOMM methods stay in the file and are not called.
3. `swift build -c release --product OpenBuds` from `native/` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
4. Install with `native/scripts/build-app.sh --install` only when a human is ready to test on the buds. That restarts `/Applications/OpenBuds.app`.
5. Hardware check, in this order, with the website connected on channel 15 first so coexistence is the thing under test:
   - Mac app reaches model `065414` and shows battery.
   - The website stays connected the whole time.
   - Toggle noise control on the Mac app. The website shows it without a reconnect.
   - Toggle noise control on the website. The Mac app shows it without a reconnect.
   - Quit neither app to make the other work.
6. Only after step 5, attempt one large command (save a custom preset, or write the gesture table). Record whether CoreBluetooth accepts the frame, the frame length, and `canSendWriteWithoutResponse`. Write that into `docs/protocol.md` and `docs/heymelody/evidence/kept-local/gatt-link.md`. Do not add a splitter in this change.

## Done when

- A connected website and the Mac app are both live, and a noise-control change on either side appears on the other.
- The Mac app's bluetoothd log shows a GATT session and no `PeerOpenRFCOMM` from `com.yashasewi.openbuds` during that session.
- Model check, refresh, and the existing command timeout still behave as they do on RFCOMM.
- A too-large write fails visibly and names its length.
- `docs/protocol.md` describes the GATT path with the parent service UUID filled in from the run, or an explicit note that discovery did not find `0100079A-…` / `0200079A-…`.
- `swift build -c release --product OpenBuds` succeeds. The web app is unchanged, so its checks stay green without edits.

## If discovery fails

Stop. Capture the service and characteristic UUIDs CoreBluetooth returns and put them in the evidence note. Do not scan, do not open channel 15, and do not try the AI or CTKD characteristics as a substitute write endpoint.
