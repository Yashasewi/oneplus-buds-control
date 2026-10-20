# Read-only feature validation and first web version

On 2026-10-12 the user ran the diagnostic page in normal Chrome on macOS with OnePlus Buds 4, model `065414`, firmware `138.138.105`. This followed explicit authorization for read-only inventory, temporary event registration, one reconnect and the first web version. Device-setting changes, tests/sounds, reset and updates remain outside scope.

Evidence: [FEATURE-VALIDATION-001](evidence/feature-validation.json), the immutable [88-record session](evidence/feature-validation-session.json), and the user-supplied [nine-page PDF](evidence/user-feature-validation.pdf) with [USER-003 provenance](evidence/user-feature-validation.json). The PDF exports the same run; it is not an independent protocol implementation. The session spans `14:41:38`–`14:42:32` UTC and ends with `validation_passed`.

## Verified queries

Both connections completed the same 16 transactions: 15 reads and one temporary event subscription. All 32 requests received corresponding replies. No query error or device-setting command appears in this capture.

| Request → reply | Captured result / boundary |
|---|---|
| `0100 → 8100` | Capability payload `00 FF 77 5A EA 67 0E 20 07`. |
| `0103 → 8103` | Model payload `00 14 54 06`, matching `065414`. |
| `0105 → 8105` | Version records decoded as `138.138.105`, matching the earlier screenshot. |
| `0106 → 8106` | Left/right 80%, not charging. Case battery absent. |
| `0109 → 8109` | Initial wearing values left/right `7`, case `4`. |
| `010C → 810C` | Selector `[1,1]`; initial raw mode `8` (Off), reconnect raw `256` (Transparency). Other modes remain externally documented, not observed in this run. |
| `010F → 810F` | EQ `0`, interpreted as Balanced using target configuration and external protocol evidence. |
| `0122 → 8122` | No custom presets: `[0,0]`. Nonempty preset layouts remain unverified on hardware. |
| `0108 → 8108` | 18 mappings, including separate left/right controls and call controls. Left slide selects tracks; right slide adjusts volume. These were read, not invoked. |
| `010D → 810D` | Queried IDs `5,4,11,17,24,6,27,29,28`; returned `5=1,4=1,11=0,17=1,24=0,6=0,27=0,29=1`. ID 28 absent; ID 5 stays unnamed in the UI. |
| `0112 → 8112` | Two connected hosts, one marked current device. Names are shown locally; MAC addresses/raw payload and host names are omitted from structured retained logs. |
| `0114 → 8114` | Codec `2`, interpreted as AAC. |
| `0124 → 8124` | Bass payload `[0,251,5,0]`, current value `0`. Other range/value variants untested. |
| `0130 → 8130` | Prompt volume `6`. Range/display interpretation comes from external protocol evidence. |
| `0200 → 8200` | Offered events `1,2,3,4,8,11,241,242,243`. Only 1/2/3 selected. |
| `0205 → 8205` | Request `[3,1,2,3]`; acknowledgement `[1,3,1,0,2,0,3,0]`. This changes session notification registration, not an earbud setting. |

State labels combine observed bytes with [QuickBuds protocol facts](quickbuds-reference.md) and native feature metadata. A switch value of zero describes a reported current state; it is not evidence that the feature is unsupported. The newer external status-query list is now confirmed to return useful values on this device. It does not resolve the original iOS fallback array's consumer semantics.

## Live events and reconnect

During the 45-second listening step, eight `0204` events arrived: five wearing, two battery and one noise-mode event. Wearing changed from left/right `7/7` to `5/7`, consistent with the left bud being removed while the right remained worn. The captured window does **not** show a return-to-in-ear transition. Noise changed to raw `256` (Transparency); the application sent no setting command. These are reported device events, not proof that the web application changed ANC.

The page closed the first connection, waited 700 ms, reopened the same granted port, repeated inventory and event registration, and received another wearing event. Noise was independently reread as Transparency after reconnect. The final connection closed automatically.

This proves the tested close/reopen path. Abrupt radio loss, simultaneous controllers, prolonged background operation, all possible events and other firmware families remain untested.

## Implemented first slice

The [web application](../../README.md) uses an independently written ES-module frame codec, read-only command allowlist, model check, capability-gated inventory, serialized transactions, command/sequence correlation, bounded streaming parser and session-generation cleanup. The dashboard presents actual values, unavailable fields and disconnected last-read state. There are no setting-change controls.

The user subsequently opened the main dashboard in normal Chrome and confirmed **“Yes, values loaded”** ([USER-004](evidence/dashboard-user-validation.json)). The diagnostic and main page share the same connection core. The main page does not save device state or raw replies to the server.

T3's collaborative browser was used for UI inspection and left/right-tab checks. Its attempted device chooser returned `NotFoundError` / no port selected; no T3 device connection was established. This does not prove Web Serial is universally unavailable in T3. Normal Chrome remains the verified device route, as requested by the user.

T3 viewport-resize calls timed out. Desktop UI was inspected directly; mobile CSS was additionally inspected with a temporary 390-pixel page width and the mobile media rules enabled. The single-column layout had no content beyond that width. This is a simulated layout check, not a mobile browser hardware test. Captured-state UI replay was explicitly marked as a test and removed before handoff.

`npm test` covers 12 cases: known hardware packets, every split boundary, byte-at-a-time reply parsing, multi-byte length encoding, malformed frames/payloads, read-only opcode enforcement, live-event replay, reconnect/stream-lock cleanup and model rejection before feature queries. Host-device decoding uses a synthetic privacy-safe fixture because its raw capture was intentionally omitted.

## Next stages

The first read-only slice is implemented and hardware verified. Ordinary setting controls require a separately agreed mutation scope, per-command acknowledgements and readback validation. Golden Sound/fit testing, find-earbud sound, OTA, cloud/account features and system integration retain the discovery gates in [the implementation plan](implementation-plan.md). A local bridge is deferred; none is required for the verified reads and events.
