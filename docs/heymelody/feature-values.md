# PeripheralFeature numeric values

Source: [NATIVE-FEATURE-001](evidence/peripheral-feature-values.json), derived from [NATIVE-SWIFT-001](evidence/swift-protocol-metadata.json) and three captured static LLDB disassembly files. This was file-only disassembly: no process ran, no debugger attached and no earbuds were accessed.

## What is established

The imported RawRepresentable witness identifies `PeripheralFeature.rawValue` at `0x1010f448c`. Its body `0x1010f37dc` loads a one-byte enum storage discriminator, indexes a 43-entry signed-relative jump table at `0x1010f3a24`, and returns explicit MOVZ constants. The getter does **not** return the reflection index: examples include storage tag 17 → raw 21, tag 21 → raw 29 and tag 32 → raw 50. All 43 instruction-derived mappings are independently matched against initializer `0x1010f3c50`, which compares raw constants and returns byte tags; unmatched input returns optional-empty tag 43.

Static type metadata `0x10168fd60` refers to the reflected PeripheralFeature descriptor, with value-witness table `0x10168fce0`, size/stride one byte. Its enum tag reader `0x1000165a0` is `ldrb w0,[x0]`; tag injector `0x1000165a8` is `strb w1,[x0]`. These observations confirm canonical enum tags equal stored byte values for this all-empty enum.

**Case names below are ABI-correlated inferences**, associating the confirmed canonical tags with the field descriptor’s 43 empty-case records. No independent named-case string switch or executed runtime-reflection test was performed. Raw numeric values and inverse conversions are established by actual code; the name association has this explicit remaining boundary.

## OnePlus Buds 4 status list

Bundled target config has `switchStatus=[4,11,6,9,12,15,17,30]`. Code-derived raw values with ABI-correlated names:

| Raw feature value | Stored enum tag | Case name candidate |
|---|---|---|
| 4 | 3 | `wearTesting` |
| 11 | 10 | `hearingEnhancement` |
| 6 | 5 | `gameMode` |
| 9 | 8 | `vocalIncrease` |
| 12 | 11 | `personalizedNoiseReduction` |
| 15 | 14 | `headsetMeditation` |
| 17 | 16 | `duplex` |
| 30 | 24 | `headsetLog` |

The `switchStatus` consumer has not been traced in this pass. This list may enumerate status values to query rather than features actually supported or visible. In particular, raw 12/15 candidates personalizedNoiseReduction/headsetMeditation do not override `personalizeDenoise=0` or the absence of `whiteNoise` in the Buds 4 fallback profile. Neither the config list nor the enum means a feature is currently enabled.

The user supplied firmware screen reports **138.138.105**, “Version up to date,” and identified macOS with Chrome (USER-001). This is user evidence; no device or vendor firmware catalog was queried.

## Full code-derived map

| Stored tag | Raw value from getter | ABI-correlated case name | Return-block address |
|---|---|---|
| 0 | 1 | `noiseReduction` | `0x1010f3814` |
| 1 | 2 | `smartNoiseReduction` | `0x1010f3820` |
| 2 | 3 | `snoreNoiseReduction` | `0x1010f382c` |
| 3 | 4 | `wearTesting` | `0x1010f3838` |
| 4 | 5 | `LHDC` | `0x1010f3844` |
| 5 | 6 | `gameMode` | `0x1010f3850` |
| 6 | 7 | `meetMode` | `0x1010f385c` |
| 7 | 8 | `autoAnswer` | `0x1010f3868` |
| 8 | 9 | `vocalIncrease` | `0x1010f3874` |
| 9 | 10 | `headsetOperation` | `0x1010f3880` |
| 10 | 11 | `hearingEnhancement` | `0x1010f388c` |
| 11 | 12 | `personalizedNoiseReduction` | `0x1010f3898` |
| 12 | 13 | `takePhotoWithHeadset` | `0x1010f38a4` |
| 13 | 14 | `debug` | `0x1010f38b0` |
| 14 | 15 | `headsetMeditation` | `0x1010f38bc` |
| 15 | 16 | `oneButtonSwitch` | `0x1010f38c8` |
| 16 | 17 | `duplex` | `0x1010f38d4` |
| 17 | 21 | `freeToPick` | `0x1010f38e0` |
| 18 | 22 | `dropReminder` | `0x1010f38ec` |
| 19 | 24 | `hiRes` | `0x1010f38f8` |
| 20 | 25 | `voiceQuickCommand` | `0x1010f3904` |
| 21 | 29 | `bassEngine` | `0x1010f3910` |
| 22 | 27 | `spatialSound` | `0x1010f391c` |
| 23 | 28 | `volumeAutoAdjust` | `0x1010f3928` |
| 24 | 30 | `headsetLog` | `0x1010f3934` |
| 25 | 34 | `neckHealthMonitor` | `0x1010f3940` |
| 26 | 35 | `neckHealthTired` | `0x1010f394c` |
| 27 | 36 | `neckHealthRoutine` | `0x1010f3958` |
| 28 | 37 | `aiMusic` | `0x1010f3964` |
| 29 | 40 | `gameEffectAll` | `0x1010f3970` |
| 30 | 48 | `adaptVolume` | `0x1010f397c` |
| 31 | 49 | `sidesAdapt` | `0x1010f3988` |
| 32 | 50 | `dialogueSence` | `0x1010f3994` |
| 33 | 51 | `superLongTap` | `0x1010f39a0` |
| 34 | 53 | `longTap` | `0x1010f39ac` |
| 35 | 55 | `swiftPair` | `0x1010f39b8` |
| 36 | 56 | `audioTuning` | `0x1010f39c4` |
| 37 | 57 | `voiceControl` | `0x1010f39d0` |
| 38 | 58 | `sleepDetection` | `0x1010f39dc` |
| 39 | 59 | `headGestureControl` | `0x1010f39e8` |
| 40 | 60 | `neckHealthTone` | `0x1010f39f4` |
| 41 | 61 | `geminiFeature` | `0x1010f3a00` |
| 42 | 62 | `unknown` | `0x1010f3a0c` |

These values are feature enum values rather than Bluetooth packet command IDs or proven byte offsets. [parse_peripheral_feature_mapping.py](evidence/parse_peripheral_feature_mapping.py) is an offline evidence-verification helper, not app/bridge/protocol implementation.

## Subsequent hardware and build status

The statements above describe their original investigation phase. [Extended read-only validation](feature-validation.md) now directly confirms firmware 138.138.105, model 065414, inventory queries, live battery/wearing/noise events and one reconnect on macOS/Chrome. The first read-only dashboard is implemented and user-confirmed. Web Bluetooth GATT, setting changes and advanced-feature parity remain unvalidated.
