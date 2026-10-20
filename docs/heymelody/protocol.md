# Earbud communication protocol

Scope: static analysis of the supplied HeyMelody executable and its packaged configuration, targeting OnePlus Buds 4. No advertisement scan, connection, read request, pairing exchange, write, test, locate sound, firmware operation or app launch was performed. Static code observations establish shipped paths, not the path actually negotiated by the physical earbuds.

## Evidence sources

- REA Mach-O observation `ev_c1967b8bea67266e87f9417733af6bbf7dfa84236369acdada9e7349566d51b5`, retained in [rea-session.json](evidence/rea-session.json): source SHA-256 `0fb1d5d2824b5aee98b439844287fb3cd266fa3b417d7a799d91a1169bc9befc`, arm64, CoreBluetooth linkage, one encrypted file page.
- RES-010 [Buds 4 profile](evidence/oneplus-buds-4-profile.json): model `065414`, vendor UUID, `gattV2=1`, `ctkd=1`, `checkResponse=true`. Configuration is not a wire specification.
- NATIVE-STRINGS-001 [native string index](evidence/native-string-index.json): format-aware file offset/virtual-address mapping of string sections, with exact source digest and original string bytes.
- NATIVE-SWIFT-001 [Swift metadata](evidence/swift-protocol-metadata.json): context descriptors, reflection fields and enum case names. Record order does **not** establish wire values or memory layout.
- [Objective-C metadata dump](evidence/objc-metadata.txt): read-only `/usr/bin/otool -ov` output from the same executable. Class implementation pointers are separate from protocol declarations whose `imp` is zero.
- [Static packet disassembly](evidence/static-packet-disassembly.txt) and [related body disassembly](evidence/static-packet-assembly.txt): LLDB file-target disassembly with `--no-lldbinit`, `target create` and `disassemble` only. No target process was run or attached. These are native-tool observations, not REA Evidence records.
- REA/Ghidra completed default analysis in 830.7 seconds after startup-deadline recovery. The [canonical export](evidence/ghidra-evidence.json) contains 89 records with profiles and coverage. Focused findings are expanded in [transport-analysis.md](transport-analysis.md), [packet-analysis.md](packet-analysis.md) and [feature-values.md](feature-values.md).

## Transport and endpoint leads

The target fallback UUID is `0000079A-D102-11E1-9B23-00025B00A5A5`. Native strings additionally contain:

| UUID family | Exact candidates | Established meaning |
|---|---|---|
| `079A` | `0000079A-D102-11E1-9B23-00025B00A5A5`; `0100079A-D102-11E1-9B23-00025B00A5A5`; `0200079A-D102-11E1-9B23-00025B00A5A5` | Target configured service candidate; consumer assigns `010…` to named write field and `020…` to named notification field, subscribing to updates. Physical properties/accessibility untested. |
| `079F` | `0000079F-D102-11E1-9B24-00025B00A5A5`; `0100079F-D102-11E1-9B24-00025B00A5A5`; `0200079F-D102-11E1-9B24-00025B00A5A5` | Alternative endpoint candidates; target routing unresolved until code trace. |
| Other vendor | `0100079C-D102-11E1-9B23-00025B00A5A5` | Consumer assigns a matching candidate to the named CTKD-trigger field. Handshake semantics unresolved. |
| SIG-base-shaped | `000008A4-0000-1000-8000-00805F9B34FB`; `00000001-0000-1000-8000-00805F9B34FB`; `00000002-0000-1000-8000-00805F9B34FB`; `00000004-0000-1000-8000-00805F9B34FB` | Exact strings only; do not assume standard service semantics or permitted browser access. |

`BTManager` has actual Objective-C implementation entries for CoreBluetooth discovery, connection, service/characteristic enumeration, incoming values and notification-state updates:

| Callback | Original implementation address |
|---|---|
| `centralManager:didDiscoverPeripheral:advertisementData:RSSI:` | `0x100b402dc` |
| `centralManager:connectionEventDidOccur:forPeripheral:` | `0x100b407b8` |
| `centralManager:didConnectPeripheral:` | `0x100b4135c` |
| `centralManager:didFailToConnectPeripheral:error:` | `0x100b42544` |
| `centralManager:didDisconnectPeripheral:error:` | `0x100b44154` |
| `peripheral:didDiscoverServices:` | `0x100b4f1a8` |
| `peripheral:didDiscoverCharacteristicsForService:error:` | `0x100b4f8c8` |
| `peripheral:didUpdateValueForCharacteristic:error:` | `0x100b52414` |
| `peripheral:didUpdateNotificationStateForCharacteristic:error:` | `0x100b527d8` |

These pointers establish declared implementations; their full behavior requires body analysis. The app also contains `readValueForCharacteristic:`, `writeValue:forCharacteristic:type:`, `setNotifyValue:forCharacteristic:`, `readCharacteristic`, `writeCharacteristic`, `notifyCharacteristic`, `ctkdTriggerCharacteristic`, `gattV2Style`, `gattAttVerificationCompleted`, and legacy fallback naming. Exact string locations are in NATIVE-STRINGS-001.

Focused Ghidra traces now connect characteristic enumeration to UUID matching, notification subscription and named field setters. [Transport traces](transport-analysis.md) retain addresses, evidence IDs and the distinction between shipped matching behavior and actual device properties.

`PollCommands.getGATTOverEdrState` is a real reflected enum case, and transport state contains GATT/CTKD-related fields. This establishes that the shipped app represents such a query/path; it does not establish BR/EDR transport for the user’s current session. GATT-over-BR/EDR is distinct from RFCOMM/SPP. No RFCOMM endpoint has been established in this investigation.

For browser implications, see [web-bluetooth.md](web-bluetooth.md): permitted reachable GATT is a direct-browser candidate; native pairing/CTKD selection may require a bridge; existing macOS CoreBluetooth-backed GATT-over-BR/EDR availability needs measurement. Do not categorically equate “classic Bluetooth” with “Web Serial can handle it.”

## Command architecture recovered from reflection

| Type | Descriptor | Observed fields/cases |
|---|---|---|
| `DecodedData` | `0x101589d74` | `type`, `data`, `errorCode` |
| `PeripheralDataTask` | `0x10159e774` | `peripheralID`, `notificationTasks`, `requestTasks` |
| `ProtocolDecoder` | `0x1015a7550` | `contentData` |
| `ResponseCommand` | `0x101596694` | `hostUTCTime`, `responseLogCommand` |
| `CommandRequest` | `0x1015a4610` | Class identity; no reflected stored fields in selected descriptor. |
| `BTCharacteristicsPrepareTask` | `0x1015a9824` | Class identity; no reflected stored fields in selected descriptor. |

These observations support a **candidate** design of per-peripheral request and notification tasks with decoded type/data/error output. They do not establish scheduler ordering, locks, retry policy, byte layout, success codes or request IDs.

### Poll/read family

`PollCommands`, descriptor `0x101593914`, has 47 reflected cases. Grouped here by semantic name, not wire group/number:

- Identity/link: `getRemoteCapablities`, `getRemoteMTU`, `getRemoteVID`, `getRemoteDeviceIdentification`, `getProtocolVersion`, `getRemoteVersion`, `getRemoteProductID`, `getRemoteEICode`, `getRemoteColorID`, `getSNCode`, `getGATTOverEdrState`, `getDeviceRestoreInformation`.
- State/settings: `getRemoteBatteryLevel`, `getEarbudsStatus`, `getUpgradingCapability`, `getKeyFunctions`, `getFeatureSwitchStatus`, `getSomeFeatureSwitchStatus`, `getAutoPowerOffTime`, `getMultiConnectInformation`, `getVolumeOfTWSMode`, `getCodecType`, `getPriorityDevice`, `getVolumeValue`, `getTouchLevel`.
- Noise: `getNoiseReductionInformation`, `getNoiseReductionSupport`, `getNoiseReductionToggle`, `getNoiseReductionToggleV2`, `getNoiseReductionSwitchMode`, `getSmartReductionInformation`, `getPersonalizedNoiseReductionResult`.
- Sound/tests: `getFilterParameter`, `getEarScanFilter`, `getEQID`, `getHighVolumeGainLevel`, `getHearingTestResult`, `getEarScanResult`, `getZenMode`, `getToneInfo`, `getCustomEQ`, `getFreeToPickTime`, `getBassEngine`, `getSpatialAudio`, `getGameEffect`, `getHeadGestureControl`, `getNeckHealthCheckInfo`.

Spelling such as `Capablities` is preserved as shipped. A query named `getRemoteMTU` is not proof that it returns ATT MTU; the payload could represent an application-layer transfer size.

### Set/control family

`SetCommands`, descriptor `0x1015a0418`, has 30 reflected cases:

`setFindMode`, `setKeyFunctions`, `switchFeature`, `compactnessDetect`, `setEQ`, `setHignVolumeGainLevel`, `synUTCTime`, `setAutoPowerOffTime`, `startOrStopHearingEnhancement`, `processHearingTest`, `processEarScanTest`, `setNoiseReductionInformation`, `setZenMode`, `setPersonalizedNoiseReduction`, `setOperationTeachingKeyFunctions`, `setToneMode`, `setCustomEQ`, `setRecoveryTimeForFreeToPick`, `setBassEngine`, `setNeckHealthDetection`, `setSpatialAudioMode`, `setGameEffect`, `setVolmueValue`, `setAITranslateState`, `setHostCapabilities`, `setDualConnection`, `setTouchLevel`, `setHeadGestureControl`, `restoreFactorySetting`, `none`.

Reflection retains associated payload type references, including names that help choose further decoder/encoder traces. These are not yet complete payload definitions. No command was sent; factory reset is an inventory observation only.

### Notifications and device-initiated messages

`NotificationCommands`, descriptor `0x10159e864`: `registerNotification`, `getRegisteredNotification`, `cancelRegisteredNotification`, `registerAllWithEvent`, `getNotificationCapabilities`, `notificationEvent`, `registerAll`.

`ReceiveCommands`, descriptor `0x10158ef00`: `hostUTCTime`, `receiveSwitchStatus`, `receiveEQID`, `receiveCustomEQ`, `recoveryTimeForFreeToPick`, `receiveBassEngineValue`, `neckHealthRelatedData`, `receiveSpatialAudio`, `versionChanged`, `earbudsTips`.

This is evidence that the app represents subscription and unsolicited/device-initiated data separately. Notification bit masks, confirmation rules, cadence, event encodings and resubscription behavior remain unverified.

### Firmware family

`OTAUpgradeCommands`, descriptor `0x10159fb58`: `sync`, `start`, `zoningStart`, `data`, `blockVerify`, `isValidationDone`, `commit`, `abort`, `transferCompleteIND`, `errorIND`.

The names support an inferred staged transfer with block verification/validation and commit/abort. They do **not** establish a safe update sequence, chunk lengths, integrity algorithm, firmware acceptance, battery logic, restart behavior, resume or recovery. No firmware was downloaded or flashed.

## Wire specification: established facts vs missing fields

### Packet-format getters: initial instruction-backed facts

NATIVE-SWIFT-001 now establishes `StandardPacketFormat` and `DefaultPacketFormat` as protocols, their requirement tables, and the concrete Poll/Set witness tables. They are not two standalone packet classes. See [the witness anchor index](evidence/swift-protocol-metadata.md).

Static instruction observations, outside the declared encrypted page:

| Function | Observed behavior | Interpretation boundary |
|---|---|---|
| Standard witness `0x1012787f4` → `0x101277ea8` | Returns low byte `0xAA` (`mov w0,#-0x56`). | A constant standard-format getter; header/magic role needs the serializer/decoder consumer. |
| Standard witness `0x101278810` → `0x101277ee0` | Adds lengths of four byte-array getters; returns one byte for count ≤127; otherwise uses bit 7, a shifted upper portion and a two-byte conversion followed by reversal. | A variable-length count representation is established. Exact maximum/field coverage and outer frame placement require the full consumer and integer-conversion helper. |
| Standard witness `0x10127882c` → `0x101278164` | Computes a two-byte value; uses `3` for a nonempty inherited standard component at witness offset `0x28`, adds `4` for a Boolean predicate, adds `16` for another inherited component at `0x38`; converts and reverses. | Likely flags/attributes. The inherited components are empty for the inspected Poll conformance; this is not a test of Poll payload presence. Bit semantics need decoder corroboration. |
| Default Boolean witness `0x101277dc4` → `0x101277ddc` | Fetches first byte of a default-format array and returns whether it is greater than `0x80`. | Predicate is exact; request/response meaning needs opcode/decoder corroboration. |
| Standard witness `0x101278864` → `0x1012783cc` | Concatenates reversed command array, current persisted transfer-ID byte, little-endian two-byte payload length (`count % 65535`), then payload array. | Structured content getter; increment timing, correlation and complete outer placement remain unknown. This is not a CRC routine. |
| Standard witness `0x101278848` → `0x101277e58` | Allocates an empty byte array. | Default empty component, role unnamed by metadata. |
| `0x101278674` | Begins with diagnostic string “已发送 - ” and builds text through protocol getters. | Logging/description helper; do not mistake it for the wire serializer. |

The field roles above are deliberately conservative: Swift witness-slot names are not stored in the inspected requirement table. Instructions establish return values and composition, while consumers establish wire roles. No executable encoder has been written from these observations.

The more detailed [packet analysis](packet-analysis.md) supersedes initial helper uncertainty where independently traced: integer helper itself emits big-endian bytes and callers reverse them; observed Poll flags are `00 00`, helper length is `payload.count + 7`, and content contains a persisted modulo-256 transfer counter. It also correlates all 47 Poll branches to emitted command bytes using identical predicates in separate diagnostic and command getters. For example, battery emits content command bytes `06 01`, version `05 01`, EQ `0F 01`, and custom EQ `22 01`. These are static emitted bytes, not validated device transactions.

This document must not serve as an executable protocol specification until each item below has an encoder/decoder anchor and validated fixture:

| Item | Current boundary |
|---|---|
| Packet variants | Protocol identities, requirement/conformance tables and concrete getters recovered; model/transport selection and outer serialization remain to be traced. |
| Header/magic, length and byte order | `0xAA` constant and variable-length/two-byte getters observed above; complete field placement and decode validation still require consumers. |
| Command/opcode IDs | 47 Poll branch correlations recovered from emitted byte arrays and same-case diagnostic literals; Set/Receive/Notification/OTA wire mappings remain incomplete. Case ordinal/config IDs must not be used as wire opcodes. |
| Checksum/CRC | Error/type names suggest integrity support; unrelated bundled CRC implementations do not identify the protocol algorithm. |
| Correlation / sequence | Persisted modulo-256 transfer byte recovered; increment timing, request matching and retry semantics unresolved. |
| Fragmentation / reassembly | Transport and application packet/MTU candidates exist; fragmentation boundary/size unknown. |
| Timeout/retry/cancellation | Task/state types exist; behavior and idempotence unknown. |
| Write type and notification direction | Candidate UUID-to-write/notification/CTKD fields traced, including subscription call; actual properties and per-path write mode unresolved. |
| Battery/noise/EQ/gesture payloads | Model options documented; complete binary encoding/decoding not established by configuration. |
| Handshake/authentication | GATT/CTKD verification candidates; no observed credential or pairing exchange. |
| Error/success codes | `DecodedData.errorCode` observed; numeric meanings and failure recovery need decoder/state traces. |

Where later Ghidra traces establish values, append the exact source address/evidence ID and independent original-byte interpretation. Decompiler pseudocode is an analysis result, not recovered source, and incomplete/indirect dispatch must stay explicit.
