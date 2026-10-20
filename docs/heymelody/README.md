# HeyMelody reconstruction investigation

Read-only investigation dated **2026-10-12**, using the explicitly requested reverse-engineer-anything skill, REA MCP and Ghidra. User-selected initial hardware target: **OnePlus Buds 4**, bundled model ID `065414`, firmware **138.138.105**, on **macOS + Chrome**. Firmware was supplied in [USER-001](evidence/user-environment.json) and subsequently confirmed by a live query in [FEATURE-VALIDATION-001](evidence/feature-validation.json).

**The initial static pass built no application and performed no device operations.** HeyMelody was not launched and no vendor endpoints were contacted. The subsequently authorized [transport validation](transport-validation.md) passed direct Chrome Web Serial RFCOMM connection and capability/model/battery queries. Settings changes, pairing, sounds/tests, resets and updates were not performed. The subsequently authorized [first read-only web version](../../README.md) is now built, and the user confirmed its dashboard loads live values in normal Chrome. See [feature validation](feature-validation.md).

## Documents

| Document | Contents |
|---|---|
| [OnePlus Buds 4](oneplus-buds-4.md) | Exact target profile, all raw fields, target feature expectations and unresolved categories. |
| [Features and UI](features-ui.md) | Broad feature map, 54 decoded NIB archives, 13 storyboards, UI actions/outlets, inferred flows and model gating. |
| [Architecture](architecture.md) | Native subsystem/type/state identities, linkage, API selectors, endpoint candidates and inference boundaries. |
| [Protocol](protocol.md) | Transport candidates, command families, packet/transaction investigation, function anchors and unresolved wire fields. |
| [Transport traces](transport-analysis.md) | Ghidra consumer traces establishing write, notification and CTKD characteristic candidates. |
| [Packet analysis](packet-analysis.md) | Component byte order, persisted transfer counter, poll payload forms and 47 command correlations. |
| [Feature values](feature-values.md) | All 43 instruction-backed feature raw values, inverse-constructor checks and naming limits. |
| [QuickBuds reference](quickbuds-reference.md) | Same-firmware external implementation, credits, RFCOMM/Web Serial route and limits of its parity claims. |
| [Transport validation](transport-validation.md) | Actual Mac/Chrome evidence, successful RFCOMM connection and bounded read-only query validation. |
| [Transport decision](transport-decision.md) | Select Web Serial for the first target; preserve remaining feature and bridge gates. |
| [Feature validation](feature-validation.md) | Hardware inventory, live events, reconnect, user dashboard confirmation and first build boundaries. |
| [Chrome DevTools setup](chrome-devtools-setup.md) | Project-local Codex MCP installation, trust registration and successful live Chrome smoke check. |
| [Payload types](payload-types.md) | 104 reflected data types, 633 fields/cases, feature-state shapes and exact source locations. |
| [Browser feasibility](web-bluetooth.md) | Primary-source Web Bluetooth/Web Serial constraints, platform support, GATT-over-BR/EDR nuance and bridge requirements. |
| [Unknowns](unknowns.md) | Questions that static evidence cannot settle and the evidence each requires. |
| [Implementation plan](implementation-plan.md) | Discovery gates, shared protocol/domain core, transport adapters, target feature order and eventual validation. |
| [Evidence index](evidence/README.md) | Source hashes, complete parsed datasets, REA records and reproducible investigation helpers. |

## Target identity and boundaries

Supplied app: `/Applications/HeyMelody.app`.

Supplied executable: `/Applications/HeyMelody.app/Wrapper/HeyMelody.app/HeyMelody`.

Executable SHA-256: `0fb1d5d2824b5aee98b439844287fb3cd266fa3b417d7a799d91a1169bc9befc`.

The inner bundle is an iOS UIKit/SwiftUI application running in an installed wrapper, not an ordinary native AppKit application. Info.plist reports app **2.30.0**, bundle `com.heytap.heymelodyI18n`, minimum OS `18.0`; Mach-O build metadata independently reports platform `2`, minimum `13.2`, SDK `26.5`. Preserve those different metadata values; neither alone proves the actual supported host set.

REA's Mach-O inspection establishes arm64 and one declared encrypted page: file offsets `[17375232, 17379328)`, `cryptid=1`. Most file-backed code/resources are outside that declared range. No decryption, extraction of runtime plaintext, resigning or application modification was attempted.

The shipped fallback whitelist contains **59 model records**, including hidden entries; bundle presence does not prove retail availability or active support. The target record has `gattV2=1`, `ctkd=1`, `checkResponse=true` and UUID `0000079A-D102-11E1-9B23-00025B00A5A5`. These are observed configuration facts. Actual transport selection, firmware, browser accessibility and handshake are separate questions.

## Interpretation rules

**Observed** means exact source bytes, parsed metadata, recovered static instructions, or primary browser documentation. **Inferred** means a suggested flow/responsibility from those observations. **Unknown** means the required body, runtime, server or device evidence has not established the claim.

Static analysis never counts as observed execution. A localized feature name is not proof of UI reachability. A configured feature/category is not automatically a Boolean. Enum declaration order and model configuration numbers are not Bluetooth opcodes. A protocol/type name is not a recovered packet specification.

Ghidra analysis completed through REA MCP after **830.7 seconds** using an ephemeral read-only import of the original artifact. Initial client/provider deadlines of 300/330 seconds were insufficient. A temporary MCP process used the already-installed REA 6.4.0/Ghidra 12.1.4 with a 1,800-second startup allowance, preserving default analysis and the original file. No installed server configuration or tools were changed. The overview reports 86,945 analyzed procedures and 127,273 strings; these are analysis inventory counts, not recovered source-method counts. The canonical [Ghidra evidence export](evidence/ghidra-evidence.json) contains 89 records.

## Initial feasibility decision

Browser-only parity is **not established**. Ordinary state/settings are direct-browser candidates if the target's actual GATT endpoint is permitted and reachable. Features dependent on native pairing/CTKD, browser-unsupported transports, OS integration or persistent lifecycle may need a local bridge. Web Serial can help only for a proven eligible RFCOMM service; it is not a substitute for GATT-over-BR/EDR.

**Follow-up:** [QuickBuds](quickbuds-reference.md) supplied a same-firmware RFCOMM lead. User-assisted [transport validation](transport-validation.md) established access and initial queries; [extended validation](feature-validation.md) confirmed inventory, live battery/wearing/noise events and one reconnect. Complete feature parity remains unestablished.

The [implementation decision](transport-decision.md) selects Web Serial as the primary transport. No local bridge is required for the verified operations; Web Bluetooth GATT remains untested.

Firmware, Golden Sound, transfers and vendor translation require their own protocol/service validation. They cannot be promised merely because the app exposes a screen. The implementation plan keeps those discovery gates explicit.

## Investigation checklist

| Requested question | Status and evidence boundary |
|---|---|
| Artifact identity / package architecture | Answered for supplied bytes; runtime supported-host behavior untested. |
| Feature map | Answered at static resource/type level, including target profile; dynamic/server/firmware availability unresolved. |
| UI flows | Partially answered: serialized wiring and copy-based flows; live layouts and navigation unobserved. |
| Internal architecture | Partially answered: modules/state/linkage and focused static traces; complete dispatch/call graph not recovered. |
| Earbud protocol | Partially answered: transport leads and command-family identities; see protocol document for verified wire facts vs remaining gaps. |
| Web Bluetooth vs bridge | Direct Web Serial RFCOMM verified on target; Web Bluetooth GATT untested; bridge deferred for tested features. |
| Implementation plan | First read-only web slice built and hardware verified; future settings/complex features retain discovery gates. |

This report includes a validated first read-only device client, not a claim of full behavioral equivalence. Outstanding items are preserved in [unknowns.md](unknowns.md).
