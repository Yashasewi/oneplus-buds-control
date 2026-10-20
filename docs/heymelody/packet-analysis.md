# Packet helpers and poll-command analysis

Read-only static findings for the inspected HeyMelody executable, SHA-256 `0fb1d5d2824b5aee98b439844287fb3cd266fa3b417d7a799d91a1169bc9befc`. This analysis establishes helper behavior and command-byte correlations. It provides no device captures, executable codec, validated firmware command set, or proof that every app command is available on OnePlus Buds 4 firmware 138.138.105.

## Evidence and dispatch

The [Swift witness metadata](evidence/swift-protocol-metadata.json) identifies `PollCommands` conformances to `DefaultPacketFormat` and `StandardPacketFormat`; these are protocols. `DefaultPacketFormat` witness table `0x10166d5a0` inherits the standard table `0x10166d560`. Observed slots identify the description wrapper `0x10098d85c`, predicate wrapper `0x101277dc4`, command wrapper `0x10098edb4`, payload wrapper `0x10098edf0`, and constant wrapper `0x10098ee2c`. Their targets below are body evidence, rather than semantic names guessed from reflection order.

The common standard helpers receive a Default witness table `W`, and resolve the inherited Standard table `S = *(W + 8)`. The standard table's slots at offsets `0x28` and `0x38` both point to the empty-array wrapper `0x101278848` for PollCommands. **These slots are distinct from the Default payload slot `W + 0x28`.** Confusing them produces an incorrect flags interpretation.

| Saved dossier | Evidence ID |
|---|---|
| [050-poll-opcode-body.json](evidence/050-poll-opcode-body.json) | `ev_b4bf72076515621345967dd8f6b38cc83dfc8ccfac1f44302a8c721d7a247389` |
| [051-packet-header.json](evidence/051-packet-header.json) | `ev_b4221704afb326cf0fd1f0e668762befbe3a7adda50a57742be20e7eb99d482f` |
| [052-packet-length.json](evidence/052-packet-length.json) | `ev_7a3521a3732db240916c9baf2604009a0c1d80efaa3b13f5a471e6811668d27d` |
| [053-packet-flags.json](evidence/053-packet-flags.json) | `ev_d94141be554b17bd0275673831a5420ff11f5987d535f1b30f1a77d40606927d` |
| [054-packet-integrity.json](evidence/054-packet-integrity.json) | `ev_c28b6e0a7da0bfc8f7a22cc0654c7047362d1e6740c16b92d25f6e55b965e9f5` |
| [055-packet-assembly.json](evidence/055-packet-assembly.json) | `ev_3170ab8a2b1d83231a95e94e167423ae00a82bbe3b07a8cc57db7c5613ba1367` |
| [060-poll-command-bytes.json](evidence/060-poll-command-bytes.json) | `ev_16750c75f0a77c213bb6cc898ccbb6026cacf60b8d9d30599ed2f6de7b0a6708` |
| [061-poll-payload.json](evidence/061-poll-payload.json) | `ev_ef856a9ec00e17670bca99c8040db585a6f93cb5c1fc1166b6a86ae5ad68a280` |
| [062-byte-encode-helper.json](evidence/062-byte-encode-helper.json) | `ev_6a86e0ee3da59b081b0a524246b259d844c1553a50beb8e00b699b284a64a649` |
| [063-global-byte.json](evidence/063-global-byte.json) | `ev_6f6731f70d5a041fe704371acaaca3b65700c62f0d5650486747b45aef9cdf22` |
| [084-global-init.json](evidence/084-global-init.json) | `ev_6211464d05afedb41a3d2a8204c67289bd20ce9bc3e792690611d775c67665b7` |
| [085-global-set.json](evidence/085-global-set.json) | `ev_62599834e68990c9676c8de2f37114c236929c1bf532214f0fb3b0258e95288f` |
| [088-common-empty.json](evidence/088-common-empty.json) | `ev_161a6a78abe8bb8544ed6532e65e7b5d984562b669f6851cc9dd938a16fc4c64` |
| [091-sequence-method.json](evidence/091-sequence-method.json) | `ev_bb488884ebc1145e5f0aaa1af6b0b37a29ae5d550337b4b3c0a0baf27506dbd1` |
| [108-sequence-init-body.json](evidence/108-sequence-init-body.json) | `ev_935a6105134c926260cf24ec4d8ffb729dd8a4c3d718ae7881a61bf7b628dfbf` |

## Integer and packet-component behavior

`0x100a5fdd8` (062) repeatedly appends the input integer's low byte, arithmetically shifts the input right eight bits, then reverses the collected array. Its own result is **big endian**, retaining the requested number of low-order bytes. Packet helpers that reverse this result produce little-endian bytes. The helper does not establish a safe representable-value check; callers require separate inspection. The saved assembly resolves misleading pseudocode return-register artifacts.

`0x101277ea8` (051) returns `0xffffffaa`; its low byte is `AA`. Position and consumption of this getter in a complete outer frame require serializer evidence outside this dossier subset.

`0x1012783cc` (054) constructs content by:

1. Reversing the command byte array from `W + 0x20`.
2. Appending the current byte at offset `0x10` in the global transfer-ID object returned by `0x1012789ec`.
3. Appending the reversed two-byte integer-helper result for `payload.count % 65535`.
4. Appending the payload byte array from `W + 0x28`.

Thus the observed content construction is `reverse(commandBytes) || transferIDByte || LE2(payload.count % 65535) || payload`. This function contains no checksum calculation. Its saved filename, `054-packet-integrity.json`, is an investigation label and supplies no CRC evidence. Likewise `0x101278674` (055) logs `已发送 - `; it is not a complete serializer.

`0x101278164` (053) constructs a two-byte little-endian flags component. Its integer is `3` when `S + 0x28` produces a nonempty array, otherwise `0`; it adds `4` when the Default predicate at `W + 0x18` is true, and adds `16` when `S + 0x38` produces a nonempty array. The predicate body `0x101277ddc` tests whether the first command-array byte is greater than `0x80`. Every valid Poll branch below emits first byte `01`, and both optional Standard arrays are empty, so those observed Poll paths produce flags `00 00`. Nonempty Poll payload does not change this conclusion.

`0x101277ee0` (052) sums the array lengths produced by Standard offsets `0x20`, `0x28`, `0x30`, and `0x38`. Call this sum `N`; these are flags, optional-empty component, structured content, and optional-empty component in the observed Poll witnesses. For Poll this yields `N = payload.count + 7`. If `N < 128`, the helper emits one byte. Otherwise it constructs `Q = (N & 0xff) | 0x80 | ((N & 0x3f80) << 1)`, encodes Q as two big-endian bytes with 062, then reverses them. This is a source-bounded bit transformation, not proof of a complete frame-length grammar, maximum accepted packet size, or negotiated transport MTU.

## Transfer ID state

The accessor `0x1012789ec` (063) runs a lazy initializer via `_swift_once` and returns the object in global slot `0x101772530`; it does not itself establish a constant byte. Initializer `0x101278c8c` (084) constructs and stores that object. Initializer body `0x101278db8` (108) uses the exact key `TransferID.storeKey`, reads `NSUserDefaults.integerForKey:`, accepts values in `0...255`, and stores the byte at object offset `0x10`; out-of-range paths trap.

`0x101278ec4` (091) reads this byte, stores `(byte + 1) % 256`, writes its value back to NSUserDefaults with the stored key, and calls `synchronize`. Wrapper `0x101278c18` (085) obtains the singleton and invokes this method. This establishes a persisted modulo-256 counter. The content helper reads the current value without incrementing it. Increment timing, request/response matching, retries, per-device behavior, and reset policy are unknown until the relevant callers are traced.

## Corroborated poll-command associations

`0x10098ae98` (060) emits a two-byte command array `[01, lowByte]`; `0x100461280` (088) directly returns `1`. Content helper 054 reverses this array to `[lowByte, 01]`. The little-endian u16 interpretation below is inferred from those observed bytes. Semantic labels are inferred by matching the exact same native case predicate against independent description getter `0x10098d898` (050), whose original UTF-8 diagnostic literal is preserved with its file offset and VM address in [poll-command-correlations.json](evidence/poll-command-correlations.json). None of these associations uses Swift declaration order to derive a wire opcode.

The JSON retains all 47 associations, explicit copied-enum predicates, observed getter/content arrays, exact diagnostic literals, and evidence IDs. Its [reproduction helper](evidence/correlate_poll_commands.py) only reads saved dossiers and the app artifact; it does not implement transport or a codec. Native copied-enum discriminator values identify branches in this build and are not wire field values.

| Inferred semantic association | Native predicate key | Observed content command bytes | Inferred LE u16 |
|---|---|---|---|
| Noise selection v2 / per-ear | `payload:0` | `0C 01` | `0x10c` |
| Selected feature switches | `payload:1` | `0D 01` | `0x10d` |
| Filter parameters | `payload:2` | `16 01` | `0x116` |
| SN information | `payload:3` | `17 01` | `0x117` |
| Ear-scan filter | `payload:4` | `1F 01` | `0x11f` |
| Priority device | `payload:5` | `32 01` | `0x132` |
| Remote capabilities | `empty:0` | `00 01` | `0x100` |
| Remote MTU | `empty:1` | `01 01` | `0x101` |
| Remote VID | `empty:2` | `02 01` | `0x102` |
| Device identification | `empty:3` | `03 01` | `0x103` |
| Protocol version | `empty:4` | `04 01` | `0x104` |
| Firmware/remote version | `empty:5` | `05 01` | `0x105` |
| Battery | `empty:6` | `06 01` | `0x106` |
| OTA capability | `empty:7` | `07 01` | `0x107` |
| Control mappings | `empty:8` | `08 01` | `0x108` |
| Earbud wearing/box state | `empty:9` | `09 01` | `0x109` |
| EI code | `empty:10` | `0A 01` | `0x10a` |
| Color | `empty:11` | `0B 01` | `0x10b` |
| Noise reduction information | `empty:12` | `0C 01` | `0x10c` |
| Noise reduction support | `empty:13` | `0C 01` | `0x10c` |
| Selected noise reduction option | `empty:14` | `0C 01` | `0x10c` |
| Noise switch-mode query | `empty:15` | `0C 01` | `0x10c` |
| Smart noise information | `empty:16` | `0C 01` | `0x10c` |
| Feature switches | `empty:17` | `0D 01` | `0x10d` |
| Product ID | `empty:18` | `0E 01` | `0x10e` |
| EQ selection | `empty:19` | `0F 01` | `0x10f` |
| High-volume gain | `empty:20` | `10 01` | `0x110` |
| Auto power-off | `empty:21` | `11 01` | `0x111` |
| Multiple connections | `empty:22` | `12 01` | `0x112` |
| TWS speaker volumes | `empty:23` | `13 01` | `0x113` |
| Codec | `empty:24` | `14 01` | `0x114` |
| Hearing-test result | `empty:25` | `15 01` | `0x115` |
| GATT-over-EDR state | `empty:26` | `1B 01` | `0x11b` |
| Stored device information | `empty:27` | `18 01` | `0x118` |
| Zen state | `empty:28` | `19 01` | `0x119` |
| Personalized ANC result | `empty:29` | `1A 01` | `0x11a` |
| Ear-scan result | `empty:30` | `1E 01` | `0x11e` |
| Tone information | `empty:31` | `21 01` | `0x121` |
| Custom EQ | `empty:32` | `22 01` | `0x122` |
| Free-to-pick recovery time | `empty:33` | `1D 01` | `0x11d` |
| Bass engine | `empty:34` | `24 01` | `0x124` |
| Spatial audio | `empty:35` | `2A 01` | `0x12a` |
| Game effect | `empty:36` | `2B 01` | `0x12b` |
| Volume | `empty:37` | `30 01` | `0x130` |
| Touch pressure level | `empty:38` | `33 01` | `0x133` |
| Head gestures | `empty:39` | `34 01` | `0x134` |
| Neck-health calibration | `empty:40` | `29 01` | `0x129` |

Some descriptions share a command byte pair: all five empty noise-query branches and the per-ear noise branch emit `0C 01`, with selectors carried in payload. The semantic table is evidence for emitted query identifiers, not proof of response fields, mutation commands, capability eligibility, or target firmware support.

The feature-switch descriptions at `0D 01` establish a general feature-query association. Swift metadata lists `duplex` in `PeripheralFeature`, but this dossier subset does not establish its raw feature number or the query payload byte that selects it. Controls, battery, protocol/version, MTU, EQ and custom EQ have direct same-predicate description corroboration as shown above; duplex still requires a raw-value getter and model capability correlation. The MTU query's diagnostic label does not expose negotiated ATT MTU to browser JavaScript or prove a transport.

## Observed poll payload forms

Payload getter `0x10098c794` (061) handles the same copied enum representation as the description and command getters. The following forms are local helper outputs; semantic associations are inferred from the same-case descriptions. Associated Swift field types alone do not validate a complete binary schema.

| Branch and inferred semantic association | Directly observed output / unresolved portion |
|---|---|
| Empty 12, noise information | `01 01` |
| Empty 13, noise support | `03 01` |
| Empty 14, selected noise option | `02 01` |
| Empty 15, switch-mode query | `02 01` |
| Empty 16, smart noise | `04 01` |
| Other valid empty branches | Empty payload array |
| Payload 0, per-ear noise v2 | Supplied byte 0 → `02 03`; byte 1 → `02 04`; other → `02 01`. Exact side/raw-value semantics require the associated enum's getter. |
| Payload 1, selected feature switches | A mapped feature list preceded by its one-byte count. Mapping closure/raw-value behavior remains untraced here. |
| Payload 2, filter parameters | A mapped list, reversed four-byte integer-helper result, and ASCII-encoded string; count byte is prepended. Mapping closure and exact field applicability remain untraced here. |
| Payload 3, SN information | Supplied byte array preceded by its one-byte count; count outside UInt8 range follows a trapping path. |
| Payload 4, ear-scan filter | Two little-endian bytes of Data length, Data bytes, four little-endian bytes of the supplied integer, then ASCII string bytes. No `% 65535` operation is observed at this branch's length-encoding call. String conversion failure behavior and overflow acceptance require the caller/helper paths. |
| Payload 5, priority device | One supplied byte. Its wire meaning is not proven. |

No battery/wearing/EQ/controls response decoder is established by these poll getter outputs. See [payload-types.md](payload-types.md) for reflected model fields and enum identities; those are distinct evidence from a byte parser.

## Remaining boundaries

This page deliberately does not claim a complete outer frame, CRC, fragmentation scheme, timeout/retry rules, notification registration, receive opcode mapping, authentication, or supported GATT characteristics. The build-wide poll table cannot establish Buds 4 capability availability. BLE GATT and GATT over BR/EDR remain transport candidates until characteristic discovery code and a separately authorized device inspection resolve them; RFCOMM is a distinct transport. [web-bluetooth.md](web-bluetooth.md) records the browser constraints independently.

The separate [feature-value analysis](feature-values.md) now recovers all 43 `PeripheralFeature.rawValue` numbers with inverse checks; selected-feature payload mapping and the configuration consumer still need joining to that evidence. [Transport traces](transport-analysis.md) establish candidate characteristic roles but not physical endpoint availability.

Next static work should join these helpers to the concrete outer serializer and write path, decode replies and notifications, trace control/action getters and transfer-ID increment callers, and bind commands to the Buds 4 resource capability configuration. Any actual earbud probing or packet replay remains outside this investigation's authorization.
