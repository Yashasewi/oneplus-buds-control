# Implementation plan and progress

Target selected by the user: **OnePlus Buds 4** (`065414`), firmware **138.138.105** (USER-001 screenshot and FEATURE-VALIDATION-001 live query), on **macOS + Chrome**. Broader HeyMelody parity is a separate expansion across the 59 bundled model profiles. After the initial investigation, the user authorized read-only hardware validation and the first web version. The read-only dashboard is now built and verified; no Bluetooth bridge, setting changes or firmware tool was implemented. See [feature validation](feature-validation.md) and [run instructions](../../README.md).

## Definition of a functional reconstruction

A functional feature must read actual device state, accept only device-supported options, perform a verified transaction when the user requests a change, and reconcile the acknowledged result. A matching screen, bundled localization key, or successful transport connection is insufficient.

Use [the target profile](oneplus-buds-4.md) for initial scope, [the UI map](features-ui.md) for screen candidates, [the architecture investigation](architecture.md) for original subsystem evidence, [the protocol investigation](protocol.md) for transaction facts, and [the browser assessment](web-bluetooth.md) for API constraints. Anything marked unknown remains a discovery gate, not an implementation assumption.

## Stage 0: finish evidence before implementation authorization

1. Preserve executable identity, original file offsets/addresses, Ghidra provider/profile, source resource hashes, and full REA records. Associate each protocol claim with the function and source bytes establishing it.
2. Resolve the target's physical firmware version, intended browser/OS, and pairing state when those affect the next step. Do not require this information for offline investigation.
3. Recover service/characteristic selection, GATT v2 and legacy fallback, any GATT-over-BR/EDR and CTKD paths, and transport verification. Distinguish GATT-over-BR/EDR from RFCOMM; Web Serial is relevant only if a real RFCOMM service exists.
4. Recover packet fields, endianness, declared-length rules, integrity check, command groups and IDs, request/response matching, notifications, fragmentation, retry/deadline/cancellation, and model-specific payloads. Never derive opcodes from configuration field numbers or enum declaration order.
5. Complete the OnePlus Buds 4 switch-status mapping, noise mode values, EQ structure, Golden Sound transactions, wearing/battery encodings, and runtime capability negotiation.
6. Preserve a bounded unknown list for cloud APIs, authentication, regional entitlements, paid translation, hearing computations, and high-impact transfer/update features. Offline URL strings do not prove accessible or reusable services.

Exit: a reviewable protocol specification and transport decision, with unsupported features explicitly classified. This investigation does not authorize implementation or device validation.

Current progress: target firmware and browser/OS are supplied; default Ghidra analysis and evidence preservation completed. Write/notification/CTKD candidates are traced, packet components and 47 Poll correlations recovered, and all 43 feature raw values inverse-checked. Direct RFCOMM access, tested outer-frame/response correlation and target read-only inventory/events are now verified. Remaining Stage 0 work includes full native configuration consumers, untested frame/error variants and advanced-feature transactions. See [transport traces](transport-analysis.md), [packet analysis](packet-analysis.md) and [unknowns](unknowns.md).

## Stage 1: shared domain and protocol core

The [QuickBuds follow-up](quickbuds-reference.md) supplies a same-firmware RFCOMM implementation and detailed frame/read/write/event documentation. Use it to narrow Stage 0 traces and compare fixtures. Assess Chrome Web Serial custom-service access before deciding a bridge is required. Preserve external evidence separately and account for its GPL license before any code reuse; OTA/cloud exclusions mean it does not establish full parity.

Design a browser-independent core that can be replayed offline:

- `DeviceIdentity`: raw model ID, display name, firmware/protocol versions and observed capabilities.
- `DeviceState`: left/right/case battery and charging, connection/wearing, noise selection, sound settings, gestures, host connections and firmware status. Represent missing/unknown/stale values explicitly.
- `CapabilityResolver`: bundled fallback + firmware/app conditions + observed feature report + region/account eligibility. Keep numeric categories distinct from booleans. Retain source/provenance when an override changes a capability.
- `PacketCodec`: validated binary encoder/decoder with model/protocol dispatch, bounded input lengths and integrity validation. No transport side effects.
- `TransactionScheduler`: request correlation, command-specific responses, notification routing, timeouts, cancellation, backpressure, reconnect invalidation and verified retry policy.
- `EarbudService`: typed operations such as reading state, selecting noise mode, setting a gesture, managing EQ and starting a verified test. Return observed results and errors; do not optimistically declare a device change successful.

The eventual core should share transaction semantics across transports. Do not model every original class one-for-one; the shipped class names identify investigation seams, not a required web design.

## Stage 2: transport adapters and local bridge decision

**Decision after authorized validation:** [choose Web Serial](transport-decision.md) for the first Chrome/macOS target. Connection, capability, matching model and battery queries passed on the user's device. A bridge is deferred for basic control transport. Extended inventory/events and one reconnect passed; the first read-only app is implemented. The local development server serves the app and optional diagnostic evidence, not Bluetooth transport. Setting writes and advanced features retain their discovery/authorization gates.

Proposed interface, subject to recovered transport semantics:

| Contract | Responsibility |
|---|---|
| `select/connect/disconnect` | Explicit user selection, connection lifecycle, session generation. |
| `discover` | Actual service/characteristic availability and properties; report mismatch. |
| `receive` | Ordered incoming byte/event stream and disconnect/error events. |
| `send` | Bytes plus write semantics and completion; preserve transport constraints. |
| `limits` | Measured effective chunk size and write backpressure. Do not assume JS controls ATT MTU. |
| `availability` | Browser/host support, permissions and concrete reason for bridge fallback. |

Preferred order is conditional: Web Bluetooth for a reachable permitted GATT control endpoint; desktop Web Serial only for an observed supported RFCOMM endpoint; local bridge where those fail or native APIs are necessary. Do not use a generic RFCOMM bridge for an earbud that exposes only GATT-over-BR/EDR.

For a macOS bridge, evaluate CoreBluetooth against the actual earbud transport and OS support. A desktop wrapper is an alternative delivery choice. Other OS adapters must be evaluated independently. The bridge should handle discovery/connection and transport bytes while the shared protocol core owns command semantics, unless a native-only operation makes that impossible.

A localhost bridge should use explicit session pairing and origin validation, bind locally, expose a small versioned interface, and report permissions/errors to the UI. Design this as a product boundary, without granting arbitrary device or filesystem operations to web pages. Packaging, browser local-network rules and user installation/update UX need verification at implementation time.

Exit: recorded evidence that the selected adapter can access the control endpoint for the target model and firmware. The authorized bounded hardware validation is complete for current reads/events/reconnect. Broader transport and mutation validation needs its own scope.

## Stage 3: first OnePlus Buds 4 feature slice

Start with connection UX and observed dashboard state. Then add ordinary controls only after their transactions are recovered:

1. Device selection, pairing guidance, remembered devices, connect/reconnect/disconnect and unavailable-transport states.
2. Model/firmware identity and left/right/case state, including unavailable case telemetry and stale values.
3. Noise control: ANC, Adaptive, Transparency and Off; retrieve actual allowed modes instead of relying only on fallback.
4. Presets: Balanced (`0`), Serenade (`1`), Bass (`2`) **as configuration IDs**, then confirmed wire mapping; custom EQ and bass controls.
5. Per-ear gestures/call bindings and selected hold-to-cycle noise modes, with supported action restrictions.
6. Dual connection, game mode, wearing/auto-pause settings, prompt volume and target-supported spatial sound.

Implement model-specific visibility and precise failure states throughout. Do not expose generic head tracking, neck health, voice commands, sleep detection, translation or white noise on this target solely because the app includes their strings.

## Stage 4: complex and asynchronous features

Golden Sound and ear-fit testing need a separate state machine: eligibility → wearing/connection/environment prerequisites → initiation → progress and interruptions → result → audition/apply/save/history. Recover actual test calculations, earbud-side tasks and audio routing before implementing them. Browser-generated tones alone do not establish equivalence.

Find earbuds, sound transfers, headset-log exports, tone/theme application and firmware updates require separately validated procedures. Locate/test commands can produce sound; logs can alter connection mode; transfer/update changes persistent state. Their future validation must have explicit scope and prerequisites. This investigation performs none of them.

Firmware update must cover artifact provenance, compatibility, integrity/authentication, preparation, battery/case requirements, chunking, acknowledgements, resume, reboot, failure and recovery before enablement. A bridge may improve transport/lifecycle control but cannot supply missing update semantics or guarantee safety.

## Stage 5: cloud, audio and cross-model parity

Separate local hardware controls from cloud-backed services. Reconstruct translation UI only after eligibility, audio formats/routing, service access, account/region/quota and purchasing rules are understood. Vendor cloud reuse, paid entitlements and authentication are unresolved; a replacement provider would be a new implementation choice with different semantics.

Use ordinary web audio/media APIs for host playback where they meet the confirmed feature behavior. System Bluetooth audio profiles, OS pairing and whole-system output routing are outside Web Bluetooth. Device DSP configuration may still be a GATT operation; host-rendered spatial/audio behavior is a different task.

Expand by explicit model/protocol families and firmware fixtures. Bundle presence or a hidden model record is not sufficient to advertise retail support. Full parity includes consent/account/support flows, disconnected states, update UX, errors and model gating, not just dashboard controls.

## Validation plan for the eventual build

Use recovered/reviewed packet fixtures and controlled captures, with source identity and authorization recorded:

- Independent known-answer packets for integrity checks, endianness and command payloads.
- Valid frames, partial/combined frames, invalid integrity, declared-length mismatch and unknown command handling.
- Request/notification interleaving, duplicate/late responses, cancellation, disconnect/reconnect, transport backpressure and chunk boundaries.
- Target capability/version gates, category-vs-boolean behavior, and stale/unavailable state.
- Shared behavior across browser and bridge adapters using recorded streams.
- Passive UI comparisons for visible target-supported screens and error states.
- Separately authorized hardware validation, beginning with inventory/read operations and adding persistent changes only when explicitly requested.

The first build has 12 passing tests covering captured packet decoding, streaming and malformed input, read-only enforcement, event replay, reconnect/lock cleanup and wrong-model rejection. T3 was used for UI checks; the user confirmed main-dashboard live values in normal Chrome. The test fixture is a frozen session; its retained paired-host data is redacted. See [feature validation](feature-validation.md).

Next milestone: agree a bounded setting-change scope, validate acknowledgement and readback for ordinary controls, then expose those controls. Acoustic tests, transfers, updates, cloud services and cross-model parity remain later stages.
