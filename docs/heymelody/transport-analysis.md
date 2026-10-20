# Characteristic assignment and transport traces

Static REA/Ghidra observations for the executable identified in [README.md](README.md). No app execution or Bluetooth interaction occurred. These findings establish shipped matching behavior; they do not establish advertisements, properties, selected transport or accessibility of the user's Buds 4.

## Traced assignment path

The characteristic-discovery callback at `0x100b4f8c8` forwards to `0x100b4f4b4`. Its task-processing path reaches `0x100c814e0`, which iterates characteristics with closure `0x100c83184`; that closure forwards to assignment body `0x100c8204c`.

The assignment body obtains `characteristic.UUID.UUIDString`, compares it to a special AI notification string, then tests membership in notification, write and CTKD candidate arrays. Matching notification branches call `setNotifyValue(true, characteristic)`. The ordinary branches also invoke setters for the named `notifyCharacteristic`, `writeCharacteristic` and `ctkdTriggerCharacteristic` fields.

Field identities are independently established through Objective-C named ivar-offset variables and getter/setter instructions, retained in [NATIVE-LAYOUT-001](evidence/bluetooth-class-layout.md). They were not inferred from Swift reflection field order or presumed object offsets.

| Matching candidate | Observed consumer behavior | Boundary |
|---|---|---|
| `0200079A-D102-11E1-9B23-00025B00A5A5` | Notification array membership; subscribes and calls named notification setter `0x10115c40c`. | Actual support/properties and permission eligibility untested. |
| `0100079A-D102-11E1-9B23-00025B00A5A5` | Write array membership; calls named write setter `0x10115c16c`. | Actual write type, maximum length and readiness policy unresolved. |
| `0100079C-D102-11E1-9B23-00025B00A5A5` | CTKD array membership; calls named CTKD-trigger setter `0x10115c2bc`. | This does not establish pairing keys, trigger payload or handshake ordering. |
| `0200079F-D102-11E1-9B24-00025B00A5A5` | Special equality branch subscribes and logs an AI notification diagnostic. Also present in notification candidates. | Target routing and AI capability unknown. |
| `00000002-0000-1000-8000-00805F9B34FB` | Ordinary notification candidate array. | Do not infer standard semantics from SIG-base shape. |
| `00000001-0000-1000-8000-00805F9B34FB` | Write candidate array. | Same semantic/browser eligibility boundary. |
| `00000004-0000-1000-8000-00805F9B34FB` | CTKD-trigger candidate array. | Same handshake boundary. |

The resource profile identifies `0000079A-D102-11E1-9B23-00025B00A5A5`; initializer `0x1003553f0` places it in a CBUUID candidate array with other values, including `000008A4-0000-1000-8000-00805F9B34FB`. This is a service-discovery lead, not an observed service inventory. The precise `readCharacteristic` assignment remains unresolved.

## Evidence ledger

All records below are also retained in [ghidra-evidence.json](evidence/ghidra-evidence.json), with their provider profiles, locations and limitations.

| Body / purpose | Dossier | REA Evidence ID |
|---|---|---|
| `0x100c814e0`, enumeration/readiness | [109](evidence/109-characteristics-ready-body.json) | `ev_92548e129500c0f5bb2cc20cf36aa9e45ee4e98218505cf3e54262a1feef7f34` |
| `0x100c83184`, iteration closure | [113](evidence/113-characteristic-foreach-closure.json) | `ev_0082c232f300f476b5cfa96d946bed49aeaf1d1f1e39ea7c1a8043b01c0a5ffa` |
| `0x100c8204c`, matching and assignment | [115](evidence/115-characteristic-assignment.json) | `ev_3f66e9df762624edfa2d5c3111c13aec16b3ff5b87483989585e3172d186bd68` |
| `0x1003556ec`, notification array | [080](evidence/080-uuid-char1.json) | `ev_a3ec7dce3d0ecefe87b9a3f85f6bfcaa94dea72240a477c528fd03aa8f06f65c` |
| `0x100355820`, write array | [081](evidence/081-uuid-char2.json) | `ev_e05eb62723daf493f393409725fb6b79cdf543e2c715738ce6941f7decbcc081` |
| `0x1003557a4`, notification array accessor | [116](evidence/116-notify-list-getter.json) | `ev_cdfeee2c91030022a113af73d655092017c2b972f4b0df8315e83a1100d70b89` |
| `0x1003558c8`, write array accessor | [117](evidence/117-write-list-getter.json) | `ev_4196fd19babe8d8a8f5a6d85cd814bf4041b4c9fdec53b1c367a11273afe34c8` |
| `0x1003559ec`, CTKD array accessor | [118](evidence/118-ctkd-list-getter.json) | `ev_1dcac321eb9714d8a360f24fc1a703c70e06fd34d55d91d253118986ab21d85c` |
| `0x100355944`, CTKD array initializer | [121](evidence/121-ctkd-uuid-init.json) | `ev_f0e470bc0432bb61abbbc43995ce93a81f7cdeabe1b003acd653f1fb2a82123c` |
| `0x100355328`, AI string initializer | [122](evidence/122-ai-uuid-init.json) | `ev_a7f873de97ac868b6851b29fcb3004c3f0cc9b0bf0fb2ac864099e9704cf97b9` |
| `0x1003553f0`, CBUUID candidate array | [073](evidence/073-uuid-getter1.json) | `ev_d1701d796add3ca1ad57e57c82a5cb4b9fa06a193f96cbd95b416fc31acd5919` |

Dossier filenames are analyst labels; evidence IDs and addresses identify the observations. Decompiler output remains subject to indirect-dispatch and Swift calling-convention limitations.

## Incoming data and lifecycle

The value-update callback body `0x100b4f9b8` and request/frame-processing body `0x100b24fc4` have retained full parent dossiers in [072](evidence/072-values-body.json) and [075](evidence/075-frame-parser-body1.json). Their projected pseudocode requests exceeded a resource limit; the separately retained text views are bounded excerpts and must not be treated as complete bodies. Parent records are `ev_be25a9a2ce1f14d93c99102680ab871719c5ece7461313a2d61e25cfca101481` and `ev_24170592e15a4949e27d6dee9ca1fc44b394c4d71bf1484b6230e05f09ff5b3d`.

These traces support an architecture with characteristic preparation, subscribed incoming data and request/notification dispatch. They do not settle timeout/retry behavior, complete reply schemas or the selected transport. The separate CTKD/connection path, including `0x101243fc4`, remains only partially recovered.

## Browser and bridge decision

The recovered vendor notification/write candidates provide concrete endpoints for a future eligibility check. They do not establish that Chrome's chooser can discover the earbuds or that the permitted GATT service is reachable on this firmware and Mac.

Follow [web-bluetooth.md](web-bluetooth.md) for primary-source API constraints. Direct settings control remains conditional on actual permitted GATT access. A local bridge is required for any necessary native pairing/CTKD or OS-only operation the browser cannot perform; whether those operations are required for this target remains unknown. GATT-over-BR/EDR and RFCOMM are different paths, and no RFCOMM service has been established here.
