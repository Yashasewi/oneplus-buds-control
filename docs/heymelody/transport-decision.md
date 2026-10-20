# First-target transport decision

Date: 2026-10-12. Target: OnePlus Buds 4, live-confirmed firmware 138.138.105, macOS 27.0.1 and updated Chrome 155.0.8059.40.

**Choose direct Web Serial RFCOMM as the primary transport for the first Chrome/macOS version.** A local bridge is not needed to establish this connection or obtain the verified inventory and live events. This decision does not declare all settings or HeyMelody features supported.

Evidence: [live validation](transport-validation.md), [DEVICE-VALIDATION-001](evidence/device-validation.json), the exact [browser result log](evidence/browser-transport-results.jsonl), [QuickBuds reference](quickbuds-reference.md), and [browser API assessment](web-bluetooth.md).

| Option | Decision |
|---|---|
| Web Serial custom RFCOMM | Primary: exact `079A` service selected/opened in Chrome, inbound data received, capability/identity/battery replies validated. |
| Web Bluetooth GATT | Alternative investigation path; shipped native candidates are traced, but this device's browser GATT access was not tested. |
| Local Mac bridge | Deferred for ordinary control; use only where verified browser/OS limitations require it. No bridge was built. |

The implementation separates its protocol/state core from Web Serial connection handling, with Web Serial stream framing, serialized transactions, reply matching and disconnect handling. Use service-class UUID `0000079A-D102-11E1-9B23-00025B00A5A5`. System pairing and browser chooser permission remain user workflows.

## Verified behavior

- User-selected Buds 4 reports matching model `065414`.
- Three bounded queries receive the matching high-bit reply commands and echoed sequences.
- Capability bitmap matches the external same-firmware capture.
- Both buds report 80% battery; missing case data stays unknown.
- Firmware, noise, EQ, gestures, feature switches, host connections, codec, bass and prompt volume were read in [extended validation](feature-validation.md).
- Battery/wearing/noise events arrived, and the granted port reopened once successfully.
- No setting commands, tests, pairing changes, resets or updates were sent by the application.

## Implementation gates still open

1. Broaden hardware fixtures for unobserved ANC states, nonempty custom EQ, errors and firmware families; resolve native fallback consumer semantics.
2. Only under a separately authorized mutation scope, verify setting changes and read back device state. A successful port or transport write is not a device-setting acknowledgement.
3. Extend the verified event registration and close/reopen path to abrupt loss, longer sessions, competing controllers and unobserved large/error variants.
4. Keep OTA, cloud/account features, native audio/pairing integration and acoustic test equivalence separate.

The initial transport-validation task is complete. The user subsequently authorized remaining read-only feature/event/reconnection validation and the first web version. The first read-only application is built and user-confirmed in normal Chrome. [Chrome DevTools MCP](chrome-devtools-setup.md) was installed earlier; the user subsequently requested T3 browser checks and manual Chrome device selection. Device-setting mutations remain outside the authorized scope.
