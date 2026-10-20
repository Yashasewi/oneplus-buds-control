# QuickBuds reference and implications

Reviewed 2026-10-12 at commit `c29e0fc206666455b5805b4966f52de490439bbc`. Sources: retained [README](evidence/quickbuds/README.md), [protocol documentation](evidence/quickbuds/docs/PROTOCOL.md), [roadmap](evidence/quickbuds/docs/ROADMAP.md), and transport/codec source indexed in [OSS-QUICKBUDS-001](evidence/quickbuds/manifest.json). No downloaded code was built or executed; no device interaction occurred.

This is external implementation evidence. Its `[CAPTURE]`, `[TESTED]` and `[VENDOR]` tags are the author's reports, not captures or tests performed in our investigation. Preserve this authority separately from HeyMelody artifact observations.

## Why this is directly useful

QuickBuds identifies **OnePlus Buds 4** as confirmed on Android, Windows and Linux. Its protocol test device has firmware `B4.1-260810-1153`, displayed by HeyMelody as **138.138.105**, matching the user's screenshot. This is a much stronger target-specific reference than a generic OPPO command list, while still not independently verifying the user's device.

The source implements classic **RFCOMM** using service-class UUID `0000079A-D102-11E1-9B23-00025B00A5A5` first and `00001107-D102-11E1-9B23-00025B00A5A5` as a fallback. The author reports the first works on Buds 4 and the second times out. Windows uses Winsock Bluetooth; Linux uses BlueZ plus RFCOMM sockets/SDP. The README instructs prior system pairing.

This establishes a concrete alternative transport implementation for the same model/firmware. It does **not** prove the inspected iOS HeyMelody build uses RFCOMM, nor invalidate its traced GATT write/notification candidates. The same UUID text can play a service-class role in an RFCOMM implementation and a configured GATT-discovery role in another app; do not collapse those transports.

## Updated browser decision

**Prioritize a future Chrome Web Serial RFCOMM eligibility check, alongside the GATT option.** Chrome's [official RFCOMM documentation](evidence/quickbuds/chrome-serial-bluetooth.txt) supports already-paired classic devices on desktop Chrome 117+, including custom service-class UUIDs via `allowedBluetoothServiceClassIds` and a `bluetoothServiceClassId` filter. The `079A` vendor UUID does not use the SIG-base suffix restricted by that documented rule. This removes that particular blocklist concern; it does not guarantee enumeration or connection.

Consequently, a bridge is **not yet established as necessary** for ordinary Buds 4 control on Chrome/macOS. If this custom RFCOMM endpoint is exposed by the Mac's shipped browser/stack, Web Serial could carry the byte stream directly. Actual chooser access, connection coexistence and stream behavior remain untested.

QuickBuds itself does not provide a macOS implementation or web client. Its non-Windows desktop transport is Linux/BlueZ code, not a portable Mac Bluetooth backend. Its optional Android bridge forwards raw bytes over loopback TCP for a desktop process on the phone; it is not a browser WebSocket/HTTP bridge and cannot be reused as a browser transport without a separate interface design.

## Protocol information supplied

| Area | External finding | Relation to our native evidence |
|---|---|---|
| Outer frame | `AA`, variable-length total, two reserved bytes, LE command, byte sequence, LE payload length, payload. Total is `7 + payload.length`. | Corroborates native component getters, Poll flags `00 00`, length sum and command reversal. Full native outer serializer remains unjoined. |
| Length encoding | Standard unsigned LEB128; author gives captures crossing 127 bytes and warns against a subtract-one variant. | Native one/two-byte formula is compatible with LEB128 in the inspected nonnegative range below 16384; no claim of identical general size handling. |
| Responses/events | Replies set command bit `0x8000`; push sequence commonly `FF`; `0204` carries event codes. | Adds concrete dispatch candidates beyond our reflected names. Native persisted counter can traverse all 256 values; do not replace it with another client's sequence policy. |
| Capabilities | `0100` returns a command bitmap; `0200` reports broadcast codes; `0205` subscribes to supported events with count first. | Supplies capability/subscription algorithms to investigate and fixtures to compare. Capability bitmap should gate feature operations. |
| Common reads/writes | Battery `0106`, wearing `0109`, ANC query `010C` / write `0404`, EQ query `010F` / selection `0406`, custom EQ `0122` / `0418`, gestures `0108` / `0401`, feature read `010D` / write `0403`. | Query IDs agree with independently recovered native Poll byte pairs. Writes and full replies remain external evidence until corroborated. |
| ANC | Buds 4 write and report masks differ; Adaptive write uses bit 11. Hold-cycle behavior needs separate handling. | Prevents assuming UI order equals wire value or identical read/write masks. |
| Feature state | Per-model query lists and actual returned states gate controls; oversized generic lists have reportedly dropped other model links. | Supports tracing the config consumer rather than treating `switchStatus` as a complete support list. |
| EQ/hearing | Custom EQ create/save/delete, IDs that can renumber, Golden Sound record/test/filter sequence and mixed field encodings. | Valuable detailed implementation leads; acoustic equivalence and native payload paths still need checks. |
| Verification | Success acknowledgement can occur without the setting taking effect; read back. | Reinforces the planned transaction/state reconciliation design. |

The external documented control-frame layout contains no trailing CRC, and the inspected builders emit no CRC in that path. This is not evidence that every HeyMelody packet variant, firmware transfer or integrity field lacks a checksum.

One material difference: QuickBuds' newer Android-derived model data gives a Buds 4 status list `05 04 0B 11 18 06 1B 1D 1C`, whereas our inspected iOS bundle preserves `[4,11,6,9,12,15,17,30]`. Keep both with provenance. Do not overwrite the original fallback or infer identical capability consumers across app versions/platforms.

## README credits

| Credited project | QuickBuds' stated use / follow-up value |
|---|---|
| [OppoPodsManager](https://github.com/Zhaoyi-ya/OppoPodsManager) | Main reference for framing, commands, ANC, gestures and feature IDs. Its fetched README says archived on 2026-09-30; existing source remains a reference. |
| [Pods-Protocol-Reverse-Engineering](https://github.com/Star-ZER0/Pods-Protocol-Reverse-Engineering) | Independent framing and broadcast-code documentation, attributed as CC-BY-SA-4.0. Its own README distinguishes higher-confidence manually analyzed material from potentially inaccurate AI-generated material; inspect those directories separately. |
| [OppoPods](https://github.com/Leaf-lsgtky/OppoPods) | Early protocol/framing reference; identified through credits, not deeply inspected in this pass. |
| [OPPO-Pods-Win](https://github.com/Zhaoyi-ya/OPPO-Pods-Win) | Model-feature reference; identified through credits, not deeply inspected here. |
| [DevPods](https://github.com/ORION2809/DevPods) | QuickBuds cites a second implementation for cross-checking. Its fetched README describes a broader local bridge/Android relay with physical validation ongoing, so its protocol claims need source-level checking before treating it as independent Buds 4 confirmation. |

QuickBuds labels its code GPL-3.0-or-later. The inspected license and credits are retained. Any eventual code reuse needs a deliberate licensing choice; protocol observations should retain provenance and documentation attribution.

## Limits and plan changes

QuickBuds' broad README parity statement has narrower scope in its roadmap: **firmware flashing, server-dependent features, AI translation and several OPPO software integrations are explicitly excluded**. It is an excellent ordinary-control reference, not a complete solution to the requested full HeyMelody reconstruction. Its “updates” feature refers to QuickBuds application updates, not earbud firmware flashing.

Next investigation steps:

1. Compare external frame/response fixtures against the native serializer/decoder and retain disagreements.
2. Trace model-specific capabilities and reconcile the two bundled status-list sources.
3. In a separately authorized device/browser phase, first assess already-paired Chrome/macOS RFCOMM eligibility for the exact custom UUID; retain GATT as a separate candidate.
4. Choose direct Web Serial, GATT, or a Mac bridge based on actual transport access. A failed browser path should not be interpreted as an unsupported earbud feature.
5. Keep OTA, cloud services and acoustic test equivalence as separate discovery gates.

No browser chooser, socket, earbud command, test, update or bridge was opened/run in this review.
