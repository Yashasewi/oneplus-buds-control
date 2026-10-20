# Reflected payload and state shapes

Target: OnePlus Buds 4. Static metadata inspection, 2026-10-12; no device, network, application execution, or build operations.

This document maps **exact shipped type identities and reflected field/enum-case names**. It does not establish Swift field value types, wire payload lengths/offsets, integer widths, byte order, case raw values, command IDs, decoder dispatch, or target eligibility. Do not turn reflection order into an opcode or raw-value mapping.

Source: [native-string-index.json](evidence/native-string-index.json), SHA-256 `0fb1d5d2824b5aee98b439844287fb3cd266fa3b417d7a799d91a1169bc9befc`. The index parses file-backed Mach-O sections and Swift nominal/field descriptors. [payload-types.json](evidence/payload-types.json) preserves the selected records, including every type-name, field-name, field-record, and field-descriptor file offset and unslid virtual address. [map_payload_types.py](evidence/map_payload_types.py) reproduces this document.

Each table shows the nominal descriptor address and the type-name string's file offset. Every field/case name has its own preferred virtual address. These are file-image locations, not ASLR-adjusted runtime addresses. Repeated names such as `Status`, `State`, or `ConnectedState` are distinct identities when their descriptor addresses differ; this document does not infer their enclosing Swift context.

Buds 4 eligibility comes from [oneplus-buds-4.md](oneplus-buds-4.md), not from the presence of a generic type. That profile positively identifies battery/wear, ANC, EQ/custom EQ/bass, controls, Golden Sound/fit, dual connection, and OnePlus 3D Audio candidates. It does not establish tracking spatial audio, head gestures, personalized ANC, or duplex priority UI. Their generic identities below are included as semantic boundaries or potential runtime-gated extensions.

## Battery and wearing

The metadata separates battery value, charging state, component type, box state, and per-ear in-box/in-ear/drop-reminder state. Exact absent/unknown sentinels, case reporting timing, and polling-versus-notification reconciliation remain unknown.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `HeadsetBattery` @ `0x10159f46c` | struct | `21327106` | `id` @ `0x1015cdf5a`; `battery` @ `0x1015cdf5d`; `isCharging` @ `0x1015cdf65`; `type` @ `0x1015cdf70` |
| `BatteryType` @ `0x10159f494` | enum | `21327176` | `leftEar` @ `0x1015cdf75`; `rightEar` @ `0x1015cdf7d`; `box` @ `0x1015cdf86` |
| `PeripheralBattery` @ `0x10159f4b0` | struct | `21327200` | `left` @ `0x1015cdf8a`; `right` @ `0x1015cdf8f`; `box` @ `0x1015cdf86` |
| `BatteryUIUpdateSource` @ `0x1015a1684` | enum | `21346640` | `polled` @ `0x1015cf98d`; `notify` @ `0x1015cf994` |
| `BoxStatus` @ `0x10158a840` | enum | `21112850` | `close` @ `0x1015af991`; `open` @ `0x1015af997`; `unknow` @ `0x1015af99c` |
| `EarbudsStatus` @ `0x10158a85c` | struct | `21112860` | `isInTheBox` @ `0x1015af9a3`; `isInTheEar` @ `0x1015af9ae`; `dropReminder` @ `0x1015af9b9` |
| `PeripheralEarbudsStatus` @ `0x10158a878` | struct | `21112880` | `left` @ `0x1015af9c6`; `right` @ `0x1015af9cb`; `box` @ `0x1015af9d1` |
| `EarbudsStatusManager` @ `0x1015895b8` | class | `21100432` | `earbudsStatus` @ `0x1015aedb0`; `_isLeftInEar` @ `0x1015aedbe`; `_isRightInEar` @ `0x1015aedcb`; `earbudsZenPlaying` @ `0x1015aede0`; `isConnectedOne` @ `0x1015aedf2`; `updateCompletion` @ `0x1015aee10` |

## Noise control and fit

Noise payload identities represent action, mode/level/side, and value lists separately. Fit result has left/right fields and a distinct `Status` identity with interruption cases. Buds 4 resource mode names do not establish the numeric encoding of these cases. Personalized ANC result is generic; fallback `personalizeDenoise=0` does not positively advertise that test on Buds 4.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `PeripheralNoiseReductionInfo` @ `0x101590e48` | struct | `21184432` | `action` @ `0x1015b69bf`; `type` @ `0x1015b69c6`; `values` @ `0x1015b69cb` |
| `NoiseReductionAction` @ `0x101590dbc` | enum | `21184272` | `current` @ `0x1015b6850`; `toggle` @ `0x1015b6858`; `support` @ `0x1015b685f`; `smart` @ `0x1015b6867` |
| `NoiseReductionType` @ `0x101590dd8` | enum | `21184304` | `mode` @ `0x1015b686d`; `level` @ `0x1015b6872`; `left` @ `0x1015b6878`; `right` @ `0x1015b687d` |
| `NoiseReductionValue` @ `0x101590e2c` | enum | `21184400` | `reduction` @ `0x1015b699b`; `close` @ `0x1015b6989`; `transparent` @ `0x1015b698f`; `listen` @ `0x1015b69a5`; `smart` @ `0x1015b6867`; `middleMode` @ `0x1015b69ac`; `weakMode` @ `0x1015b68ff`; `strongMode` @ `0x1015b68e8`; `closeMinor` @ `0x1015b68dd`; `transparentMinor` @ `0x1015b6920`; `voiceEnhanced` @ `0x1015b6931`; `adaptive` @ `0x1015b68d4`; `adaptiveWeak` @ `0x1015b693f`; `adaptiveBalance` @ `0x1015b694c`; `adaptiveStrong` @ `0x1015b695c`; `unknown` @ `0x1015b69b7` |
| `SupportNoiseReduction` @ `0x10158f95c` | enum | `21163232` | `reduction` @ `0x1015b56b1`; `listen` @ `0x1015b56bb`; `transparent` @ `0x1015b56c2`; `smart` @ `0x1015b56ce`; `close` @ `0x1015b56d4`; `adaptive` @ `0x1015b56da` |
| `NoiseReductionCategory` @ `0x10158f63c` | enum | `21161264` | `oridnary` @ `0x1015b5416`; `ef175` @ `0x1015b541f`; `aa428` @ `0x1015b5425`; `smartAndVoiceEnhance` @ `0x1015b5430`; `smartNoVoiceEnhance` @ `0x1015b5450`; `manualAndVoiceEnhance` @ `0x1015b5470`; `manualNoVoiceEnhance` @ `0x1015b5490`; `adaptiveNoVoiceEnhance` @ `0x1015b54b0`; `smartBalanceEnhance` @ `0x1015b54d0`; `smartAdaptiveLevel` @ `0x1015b54f0` |
| `SetNoiseReductionAction` @ `0x1015a03a8` | enum | `21336720` | `redetect` @ `0x1015ceaa0`; `current` @ `0x1015ceaa9`; `cancel` @ `0x1015ceab1` |
| `NoiseReductionInfoManager` @ `0x10158af40` | class | `21114704` | `_toggleNoiseReductionInfo` @ `0x1015afd60`; `_toggleNoiseReductionLeft` @ `0x1015afd80`; `_toggleNoiseReductionRight` @ `0x1015afda0`; `noiseReductionSupport` @ `0x1015afdc0`; `currentSelectedReductionInfo` @ `0x1015afde0`; `_smartModeDisplay` @ `0x1015afe00` |
| `CompactnessDetectResult` @ `0x10158fe44` | struct | `21172400` | `left` @ `0x1015b5ec0`; `right` @ `0x1015b5ec5` |
| `Status` @ `0x10158fe60` | enum | `21172424` | `ordinary` @ `0x1015b5ecb`; `good` @ `0x1015b5ed4`; `abnormalForPlayingMusic` @ `0x1015b5ee0`; `abnormalForCall` @ `0x1015b5ef8`; `abnormalForEarbusStatus` @ `0x1015b5f10`; `hostCancel` @ `0x1015b5f28`; `ratherBad` @ `0x1015b5f33` |
| `PersonalizedNoiseReductionResult` @ `0x1015a0c34` | enum | `21342736` | `success` @ `0x1015cf170`; `quietLeadsToFailure` @ `0x1015cf180`; `headsetNotGoodWearLeadsToFailure` @ `0x1015cf1a0`; `windTooLoudLeadsToFailure` @ `0x1015cf1d0`; `vibrationLeadsToFailure` @ `0x1015cf1f0`; `playingMusicLeadsToFailure` @ `0x1015cf210` |

## EQ, custom EQ, and bass

Native custom EQ represents ID/selection/name constraints and a frequency dictionary. Reflection does not reveal frequency units, gain quantization/range, band order, or QR/share-code encoding. Buds 4's three preset resource IDs must be reconciled with native EQ decoding; generic `modeType*` names are not raw-value proof.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `EarbudsEQID` @ `0x10159aa74` | enum | `21275167` | `modeType0` @ `0x1015ca340`; `modeType1` @ `0x1015ca34a`; `modeType2` @ `0x1015ca354`; `modeType3` @ `0x1015ca35e`; `modeType4` @ `0x1015ca368`; `modeType5` @ `0x1015ca372`; `modeType7` @ `0x1015ca37c`; `modeType8` @ `0x1015ca386`; `modeType9` @ `0x1015ca390`; `customEQ` @ `0x1015ca39a` |
| `EqualizerModel` @ `0x1015989c0` | struct | `21252928` | `id` @ `0x1015c8f50`; `name` @ `0x1015c9168`; `name2` @ `0x1015c916d`; `isSelect` @ `0x1015c9173`; `exclusive` @ `0x1015c917c`; `dynaudio` @ `0x1015c9186`; `minVersion` @ `0x1015c918f`; `appMinVersion` @ `0x1015c919a`; `subtitle` @ `0x1015c91a8`; `subtitle2` @ `0x1015c91b1`; `color` @ `0x1015c91bb` |
| `HeadsetEqualizer` @ `0x1015aaef8` | struct | `21430704` | `title` @ `0x1015d7220`; `image` @ `0x1015d7226`; `types` @ `0x1015d722c` |
| `CustomEQ` @ `0x101598a04` | struct | `21253035` | `id` @ `0x1015c8f50`; `isSelect` @ `0x1015c9173`; `minValue` @ `0x1015c91c1`; `maxValue` @ `0x1015c91ca`; `nameLength` @ `0x1015c91d3`; `name` @ `0x1015c9168`; `frequencyCount` @ `0x1015c91de`; `frequencyDict` @ `0x1015c91ed` |
| `CustomEQVersion` @ `0x10158f658` | enum | `21161287` | `unknown` @ `0x1015b5503`; `v1` @ `0x1015b550b`; `v2` @ `0x1015b550e`; `v3` @ `0x1015b5511` |
| `SetCustomEQAction` @ `0x1015a03c4` | enum | `21336752` | `add` @ `0x1015ceab8`; `apply` @ `0x1015ce9cb`; `delete` @ `0x1015ceabc`; `recover` @ `0x1015ceac3` |
| `BassEngineModel` @ `0x101598a48` | struct | `21253129` | `minValue` @ `0x1015c91c1`; `maxValue` @ `0x1015c91ca`; `currentValue` @ `0x1015c91fb` |
| `CustomEQQR` @ `0x1015984c4` | struct | `21250130` | `version` @ `0x1015c8df0`; `customEQLoadCategory` @ `0x1015c8e00`; `dbValues` @ `0x1015c8e15`; `name` @ `0x1015c8e1e` |
| `CustomEQQRImportResult` @ `0x1015984fc` | struct | `21250736` | `qr` @ `0x1015c8e8c`; `customEQ` @ `0x1015c8e8f` |
| `CustomEQShareCodeError` @ `0x1015985a4` | enum | `21251344` | `invalidGain` @ `0x1015c8ee0`; `invalidCharacter` @ `0x1015c8ef0`; `lengthMismatch` @ `0x1015c8f01`; `checksumMismatch` @ `0x1015c8f10`; `empty` @ `0x1015c8f21` |
| `CustomEQQRError` @ `0x1015984e0` | enum | `21250141` | `importCustomEQErrorQR` @ `0x1015c8e30`; `importCustomEQErrorCategory` @ `0x1015c8e50`; `importCustomEQDuplicateName` @ `0x1015c8e70` |

## Earbud controls and optional head gestures

Controls separate ear, button, action, and function identities. Do not equate similarly ordered resource lists and enum cases. Head gesture identities exist generically; there is no positive fallback head-gesture eligibility evidence for Buds 4. Teaching-step values and tutorial state are distinct from control command payloads.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `HeadsetEar` @ `0x101589308` | enum | `21097074` | `left` @ `0x1015ae870`; `right` @ `0x1015ae875`; `both` @ `0x1015ae87b` |
| `HeadsetAction` @ `0x10158935c` | enum | `21097110` | `none` @ `0x1015ae895`; `single` @ `0x1015ae89a`; `double` @ `0x1015ae8a1`; `three` @ `0x1015ae8a8`; `longTap` @ `0x1015ae8ae`; `slide` @ `0x1015ae8b6`; `superLongTap` @ `0x1015ae8bc`; `slideUp` @ `0x1015ae8c9`; `slideDown` @ `0x1015ae8d1`; `fastSlideUp` @ `0x1015ae8db`; `fastSlideDown` @ `0x1015ae8e7`; `superLongTapSwitch` @ `0x1015ae900`; `longVolume` @ `0x1015ae913` |
| `HeadsetControl` @ `0x101590070` | struct | `21172766` | `ear` @ `0x1015b5fd3`; `support` @ `0x1015b5fd7`; `showEar` @ `0x1015b5fdf`; `action` @ `0x1015b5fe7`; `bidirectional` @ `0x1015b5fee`; `showsub` @ `0x1015b5ffc`; `subtitleKey` @ `0x1015b6004`; `titleKeys` @ `0x1015b6010`; `button` @ `0x1015b601a`; `actionTitle` @ `0x1015b6021`; `lottieNames` @ `0x1015b602d`; `actionSummary` @ `0x1015b6039`; `currentLeftFunction` @ `0x1015b6050`; `currentRightFunction` @ `0x1015b6070`; `reductionInfo` @ `0x1015b6085`; `description` @ `0x1015b6093` |
| `ActionContent` @ `0x101593810` | struct | `21213594` | `key` @ `0x1015c45c0`; `selectedFunction` @ `0x1015c45d0` |
| `HeadsetOperation` @ `0x10159382c` | struct | `21213616` | `action` @ `0x1015c45e1`; `content` @ `0x1015c45e8`; `totalFunctions` @ `0x1015c45f0` |
| `PeripheralKey` @ `0x1015a4318` | enum | `21373242` | `left` @ `0x1015d1070`; `right` @ `0x1015d1075`; `box` @ `0x1015d107b`; `leftAndRight` @ `0x1015d107f` |
| `PeripheralButton` @ `0x1015a4334` | enum | `21373264` | `feature` @ `0x1015d108c`; `volumeUp` @ `0x1015d1094`; `volumeDown` @ `0x1015d109d`; `anc` @ `0x1015d10a8`; `middleKey` @ `0x1015d10ac`; `callKey` @ `0x1015d10b6`; `unknown` @ `0x1015d10be` |
| `PeripheralFunction` @ `0x1015a4350` | enum | `21373296` | `close` @ `0x1015d10c6`; `playOrPause` @ `0x1015d10cc`; `asulike` @ `0x1015d10d8`; `wakeupAssistant` @ `0x1015d10e0`; `googleAssistant` @ `0x1015d10f0`; `previousTrack` @ `0x1015d1100`; `nextTrack` @ `0x1015d110e`; `adjustVolume` @ `0x1015d1118`; `toggleNoiseReductionMode` @ `0x1015d1130`; `playFavSong` @ `0x1015d1149`; `previousOrNextTrack` @ `0x1015d1160`; `volumeUp` @ `0x1015d1094`; `volumeDown` @ `0x1015d109d`; `rushConnect` @ `0x1015d1174`; `answerThePhone` @ `0x1015d1180`; `hangupThePhone` @ `0x1015d118f`; `maintainThreeWayCall` @ `0x1015d11a0`; `gameModeSwitch` @ `0x1015d11b5`; `headsetMeditation` @ `0x1015d11d0`; `none` @ `0x1015d11e2`; `fastFavorite` @ `0x1015d11e7`; `spatialSound` @ `0x1015d11f4`; `rejectPhone` @ `0x1015d1201`; `answerOrHangupPhone` @ `0x1015d1210`; `playOrPauseOrStopGemini` @ `0x1015d1230`; `triggerGemini` @ `0x1015d1248`; `clearPairedRecord` @ `0x1015d1260`; `keepingVolumeAdd` @ `0x1015d1280`; `keepingVolumeReduce` @ `0x1015d12a0` |
| `EarbudsFunction` @ `0x1015946e0` | struct | `21219611` | `id` @ `0x1015c5724`; `peripheralFunction` @ `0x1015c56e0`; `isSelected` @ `0x1015c5727` |
| `EarbudsSupportNoiseReduction` @ `0x101594724` | struct | `21219728` | `id` @ `0x1015c5724`; `noiseReductionValue` @ `0x1015c5700`; `isSelected` @ `0x1015c5727` |
| `EarbudsOperationDetailType` @ `0x1015946c4` | enum | `21219584` | `peripheralFunction` @ `0x1015c56e0`; `noiseReductionValue` @ `0x1015c5700`; `longTapFunction` @ `0x1015c5714` |
| `OperationControlType` @ `0x10158f604` | enum | `21161200` | `strike` @ `0x1015b53fc`; `pinch` @ `0x1015b5403` |
| `OperationTeachingStep` @ `0x101594af4` | struct | `21221872` | `id` @ `0x1015c597b`; `keyValue` @ `0x1015c597e`; `buttonValue` @ `0x1015c5987`; `actionValue` @ `0x1015c5993`; `functionValue` @ `0x1015c599f`; `title` @ `0x1015c59ad`; `description` @ `0x1015c59b3`; `isShowing` @ `0x1015c59bf`; `isOver` @ `0x1015c59c9`; `leftOrRight` @ `0x1015c59d0`; `exp_Stage` @ `0x1015c59dc` |
| `OperationLearnStatus` @ `0x101594b54` | enum | `21222032` | `none` @ `0x1015c59f8`; `failure` @ `0x1015c59fd`; `success` @ `0x1015c5a05` |
| `HeadGestureControlPollResult` @ `0x1015a79b0` | struct | `21399664` | `mapping` @ `0x1015d3b15` |
| `HeadGestureCallNodShakeMapping` @ `0x1015a7994` | enum | `21399632` | `nodAnswerShakeReject` @ `0x1015d3ae0`; `shakeAnswerNodReject` @ `0x1015d3b00` |
| `HeadGestureGuideNotifyResult` @ `0x1015a7a04` | struct | `21399760` | `statusCode` @ `0x1015d3b52` |
| `HeadGestureGuideNotifyStatus` @ `0x1015a79e8` | enum | `21399728` | `nodSuccess` @ `0x1015d3b1d`; `shakeSuccess` @ `0x1015d3b28`; `timeout` @ `0x1015d3b35`; `interruptedByCall` @ `0x1015d3b40` |

## Feature switches and capability dependencies

Switch status uses a `feature` plus `isOn` representation; remote capability and UI startup capability enums are separate. No numeric map for Buds 4's resource `switchStatus=[4,11,6,9,12,15,17,30]` follows from these reflected case lists. `MutexFeature` identities suggest a mutual-exclusion concept but do not establish its rules or target applicability.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `PeripheralFeatureStatus` @ `0x1015a5014` | struct | `21380272` | `feature` @ `0x1015d1df8`; `isOn` @ `0x1015d1e00` |
| `PeripheralFeature` @ `0x1015a4ff8` | enum | `21380240` | `noiseReduction` @ `0x1015d1b50`; `smartNoiseReduction` @ `0x1015d1b60`; `snoreNoiseReduction` @ `0x1015d1b80`; `wearTesting` @ `0x1015d1b94`; `LHDC` @ `0x1015d1ba0`; `gameMode` @ `0x1015d1ba5`; `meetMode` @ `0x1015d1bae`; `autoAnswer` @ `0x1015d1bb7`; `vocalIncrease` @ `0x1015d1bc2`; `headsetOperation` @ `0x1015d1bd0`; `hearingEnhancement` @ `0x1015d1bf0`; `personalizedNoiseReduction` @ `0x1015d1c10`; `takePhotoWithHeadset` @ `0x1015d1c30`; `debug` @ `0x1015d1c45`; `headsetMeditation` @ `0x1015d1c50`; `oneButtonSwitch` @ `0x1015d1c62`; `duplex` @ `0x1015d1c72`; `freeToPick` @ `0x1015d1c79`; `dropReminder` @ `0x1015d1c84`; `hiRes` @ `0x1015d1c91`; `voiceQuickCommand` @ `0x1015d1ca0`; `bassEngine` @ `0x1015d1cb2`; `spatialSound` @ `0x1015d1cbd`; `volumeAutoAdjust` @ `0x1015d1cd0`; `headsetLog` @ `0x1015d1ce1`; `neckHealthMonitor` @ `0x1015d1cf0`; `neckHealthTired` @ `0x1015d1d02`; `neckHealthRoutine` @ `0x1015d1d20`; `aiMusic` @ `0x1015d1d32`; `gameEffectAll` @ `0x1015d1d3a`; `adaptVolume` @ `0x1015d1d48`; `sidesAdapt` @ `0x1015d1d54`; `dialogueSence` @ `0x1015d1d5f`; `superLongTap` @ `0x1015d1d6d`; `longTap` @ `0x1015d1d7a`; `swiftPair` @ `0x1015d1d82`; `audioTuning` @ `0x1015d1d8c`; `voiceControl` @ `0x1015d1d98`; `sleepDetection` @ `0x1015d1da5`; `headGestureControl` @ `0x1015d1dc0`; `neckHealthTone` @ `0x1015d1dd3`; `geminiFeature` @ `0x1015d1de2`; `unknown` @ `0x1015d1df0` |
| `PeripheralRemoteCapability` @ `0x1015a84b4` | enum | `21405568` | `readRemoteVersion` @ `0x1015d4260`; `batteryLevelReporting` @ `0x1015d4280`; `otaUpgrading` @ `0x1015d4296`; `keyFunctionsMap` @ `0x1015d42a3`; `earbudsStatusReporting` @ `0x1015d42c0`; `earbudFinding` @ `0x1015d42d7`; `freeMusic` @ `0x1015d42e5`; `switchFeature` @ `0x1015d42ef`; `setNoiseReduction` @ `0x1015d4300`; `detectCompactness` @ `0x1015d4320`; `EQSetting` @ `0x1015d4332`; `highVolumeGain` @ `0x1015d433c`; `isSupportMultiConnect` @ `0x1015d4350`; `setRelatedDeviceInformation` @ `0x1015d4370`; `syncHostUTCTime` @ `0x1015d438c`; `setAutoPowerOffTime` @ `0x1015d43a0`; `twsMode` @ `0x1015d43b4`; `getCodecType` @ `0x1015d43bc`; `resotreFactorySetting` @ `0x1015d43d0`; `hearingProtection` @ `0x1015d43f0`; `takePhoto` @ `0x1015d4402`; `zenMode` @ `0x1015d440c`; `concurrentRegisterNotification` @ `0x1015d4420`; `debugCommand` @ `0x1015d443f`; `remoteFirmwareInformation` @ `0x1015d4450`; `deviceRestoreInformation` @ `0x1015d4470`; `personalizedNoiseReduction` @ `0x1015d4490`; `capabilitesOrStatus` @ `0x1015d44b0`; `recoveryTimeForFree_To_Pick` @ `0x1015d44d0`; `multiConnection` @ `0x1015d44ec`; `earbudScanTest` @ `0x1015d44fc`; `operationExplore` @ `0x1015d4510`; `languageType` @ `0x1015d4521`; `earbudToneInfo` @ `0x1015d452e`; `customEQ` @ `0x1015d453d`; `hostCapabilites` @ `0x1015d4546`; `freeToPick` @ `0x1015d4556`; `bassEngine` @ `0x1015d4561`; `duplexNoReboot` @ `0x1015d456c`; `spatialSound` @ `0x1015d457b`; `smartVolume` @ `0x1015d4588`; `spatialAudio` @ `0x1015d4594`; `gameEffect` @ `0x1015d45a1`; `tips` @ `0x1015d45ac`; `promptVolCtrl` @ `0x1015d45b1`; `duplexV2` @ `0x1015d45bf`; `quickVoice` @ `0x1015d45c8`; `snCode` @ `0x1015d45d3` |
| `EarbudCapablitiesType` @ `0x1015a22e0` | enum | `21356240` | `featureSwitchStatus` @ `0x1015d0130`; `remoteColorID` @ `0x1015d0144`; `remoteVersion` @ `0x1015d0152`; `batteryLevel` @ `0x1015d0160`; `upgradeCapability` @ `0x1015d0170`; `keyFunction` @ `0x1015d0182`; `equalizerID` @ `0x1015d018e`; `notificationCapablities` @ `0x1015d01a0`; `registerAllNotificationEvent` @ `0x1015d01c0`; `noiseReductionInformation` @ `0x1015d01e0`; `earbudWearingStatus` @ `0x1015d0200`; `hearingTestResultData` @ `0x1015d0220`; `noiseReductionSupport` @ `0x1015d0240`; `smartNoiseInfo` @ `0x1015d0256` |
| `MutexFeature` @ `0x10158f978` | enum | `21163254` | `gameEffect` @ `0x1015b503b`; `equalizer` @ `0x1015b4fe8`; `spatialAudio` @ `0x1015b509f`; `dialogueSence` @ `0x1015b5548`; `voiceQuickCommand` @ `0x1015b5080`; `bassEngine` @ `0x1015b50ef` |

## Spatial sound and UI reconciliation

OnePlus spatial sound and the generic closed/fixed/track spatial-audio enum are distinct names. Buds 4's `spatialSound=2` is not proof of tracking support. State gate/reconciler fields show pending/generation/timeout terminology, not a recovered confirmation algorithm.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `SpatialSoundCategory` @ `0x10158f620` | enum | `21161232` | `OPPO` @ `0x1015b5409`; `OnePlus` @ `0x1015b540e` |
| `SpatialAudioCategory` @ `0x10158f6d4` | enum | `21161456` | `general` @ `0x1015b552b`; `aiMusic` @ `0x1015b5533` |
| `SpatialAudioMode` @ `0x1015a69a8` | enum | `21388736` | `closed` @ `0x1015d3350`; `fixed` @ `0x1015d3357`; `track` @ `0x1015d335d` |
| `SpatialAudioManager` @ `0x1015a69c4` | class | `21388768` | `_selectedSpatialAudio` @ `0x1015d3370`; `_isDisconnected` @ `0x1015d3386`; `_backgroundScene` @ `0x1015d33a0`; `spatialAudios` @ `0x1015d33b1`; `supportAudioMode` @ `0x1015d33c0`; `usedSpatialAudioKey` @ `0x1015d33e0`; `delayPlayTime` @ `0x1015d33f4`; `funtionEntry` @ `0x1015d3402`; `_isOn` @ `0x1015d340f`; `gameEffectData` @ `0x1015d3415`; `cancellables` @ `0x1015d3424`; `shouldResumeWhiteNoiseAfterTrial` @ `0x1015d3440`; `startPlayWorkItem` @ `0x1015d3470`; `switchPlayWorkItem` @ `0x1015d3490`; `pendingTrialPlayMode` @ `0x1015d34b0`; `isSwitchingTrialMode` @ `0x1015d34d0`; `$__lazy_storage_$_audioPlayerDict` @ `0x1015d34f0` |
| `DeviceStateKey` @ `0x1015aa934` | enum | `21424250` | `spatialAudioMode` @ `0x1015d6160` |
| `DeviceStateGate` @ `0x1015aa950` | class | `21424265` | `uiValue` @ `0x1015d6171`; `pending` @ `0x1015d6179`; `generation` @ `0x1015d6181`; `settleTimeout` @ `0x1015d618c` |
| `DeviceStateReconciler` @ `0x1015aaa24` | class | `21424400` | `gates` @ `0x1015d61cb` |

## Golden Sound, hearing, and ear scan

Testing, ear-scan/filter data, saved hearing profiles, and application state have separate identities. Names support a dependency inventory; their call sequence, acoustic calibration, algorithm, server role, persisted representations, and device upload format remain unknown. Frequencies named in enum cases are semantic text, not decoded IDs.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `GoldenListeningState` @ `0x101595918` | enum | `21229632` | `checking` @ `0x1015c6c90`; `earScaning` @ `0x1015c6c99`; `earScanOver` @ `0x1015c6ca4`; `leftTesting` @ `0x1015c6cb0`; `rightTesting` @ `0x1015c6cbc`; `analyzing` @ `0x1015c6cc9` |
| `GoldenListening` @ `0x101595934` | class | `21229664` | `record` @ `0x1015c6cd3`; `_state` @ `0x1015c6cda`; `_errorCode` @ `0x1015c6ce1`; `_testingProgress` @ `0x1015c6cf0`; `_earScaningSuccess` @ `0x1015c6d10`; `_startHearingEnhance` @ `0x1015c6d30`; `_noiseInturrept` @ `0x1015c6d45`; `findResult` @ `0x1015c6d55`; `$__lazy_storage_$_currentVolume` @ `0x1015c6d60`; `$__lazy_storage_$_hasCallSubject` @ `0x1015c6d80`; `$__lazy_storage_$_hasCallSubjectPublisher` @ `0x1015c6db0`; `cancellables` @ `0x1015c6dda`; `$__lazy_storage_$_earScanTimeoutWorkItem` @ `0x1015c6df0`; `$__lazy_storage_$_testingDatas` @ `0x1015c6e20`; `fittingTest` @ `0x1015c6e3f`; `resourceFetcher` @ `0x1015c6e4b` |
| `TestingEar` @ `0x1015966d8` | enum | `21234872` | `left` @ `0x1015c742b`; `right` @ `0x1015c7430` |
| `PersonlizedListeningTestingData` @ `0x10158e214` | struct | `21145856` | `volumes` @ `0x1015b3b0f`; `frequency` @ `0x1015b3b17` |
| `ProcessHearingTestParameter` @ `0x1015a6e6c` | struct | `21390368` | `key` @ `0x1015d3699`; `frequencyID` @ `0x1015d369d`; `value` @ `0x1015d36a9` |
| `ProcessHearingTestFrequency` @ `0x1015a4e1c` | enum | `21379008` | `frequency500Hz` @ `0x1015d1950`; `frequency1000Hz` @ `0x1015d195f`; `frequency2000Hz` @ `0x1015d196f`; `frequency4000Hz` @ `0x1015d197f`; `frequency6000Hz` @ `0x1015d198f`; `frequency8000Hz` @ `0x1015d199f` |
| `ProcessHearingTestAction` @ `0x1015a0370` | enum | `21336640` | `startAudition` @ `0x1015ce9b0`; `stopAudition` @ `0x1015ce9be`; `apply` @ `0x1015ce9cb`; `pause` @ `0x1015ce9d1` |
| `StartOrStopHearingEnhancementType` @ `0x1015a038c` | enum | `21336672` | `hearingDetection` @ `0x1015ce9e0`; `hearingEnhancement` @ `0x1015cea00`; `hearingProtection` @ `0x1015cea20`; `earCanalScanning` @ `0x1015cea40`; `exploreEarbudsOperation` @ `0x1015cea60`; `neckHealthCalibrate` @ `0x1015cea80`; `headGesture` @ `0x1015cea94` |
| `EarScanTestResult` @ `0x10159eb4c` | struct | `21324720` | `action` @ `0x1015cda54`; `data` @ `0x1015cda5b`; `id` @ `0x1015cda60` |
| `EarScanTestManager` @ `0x10159688c` | class | `21236432` | `alreadyUpdate` @ `0x1015c74e0`; `$__lazy_storage_$_earScanTestResultSubject` @ `0x1015c74f0`; `$__lazy_storage_$_earScanTestResultPublisher` @ `0x1015c7520`; `earScanTestResult` @ `0x1015c7550` |
| `PeripheralFilterParameter` @ `0x10158fb08` | struct | `21170976` | `id` @ `0x1015b57a0`; `key` @ `0x1015b57a3`; `totalNums` @ `0x1015b57a7`; `indexId` @ `0x1015b57b1`; `type` @ `0x1015b57b9`; `leftValues` @ `0x1015b57be`; `rightValues` @ `0x1015b57c9`; `sampleRate` @ `0x1015b57d5` |
| `PersonalizedListeningRecord` @ `0x1015a6ecc` | struct | `21391104` | `sampleID` @ `0x1015d36c3`; `sampleName` @ `0x1015d36cc`; `parameters` @ `0x1015d36d7`; `dateString` @ `0x1015d36e2`; `nameId` @ `0x1015d36ed`; `earScanData` @ `0x1015d36f4`; `arrayLeft` @ `0x1015d3700`; `arrayRight` @ `0x1015d370a`; `enhancPlan` @ `0x1015d3715`; `enhancType` @ `0x1015d3720`; `localName` @ `0x1015d372b`; `isOn` @ `0x1015d3735` |
| `EnhancedActionType` @ `0x1015a5eac` | enum | `21383584` | `preEnhanced` @ `0x1015d26e2`; `doneEnhanced` @ `0x1015d26ee`; `none` @ `0x1015d26fb` |
| `HearingProtectionType` @ `0x1015ab1b4` | enum | `21432896` | `detection` @ `0x1015d73c0`; `compensation` @ `0x1015d73ca`; `protection` @ `0x1015d73d7`; `earCanalsScan` @ `0x1015d73e2` |
| `HearingStatus` @ `0x1015ab1d0` | enum | `21432918` | `normal` @ `0x1015d73f0`; `musicInterrupt` @ `0x1015d73f7`; `musicStop` @ `0x1015d7406`; `callInterrupt` @ `0x1015d7410`; `callStop` @ `0x1015d741e`; `earbudsStatusInterrupt` @ `0x1015d7430`; `earbudsStatusNormal` @ `0x1015d7450`; `detectoinTimeout` @ `0x1015d7470`; `noiseInterrupt` @ `0x1015d7481`; `noiseNormal` @ `0x1015d7490` |
| `HearingProtectionAttribute` @ `0x1015ab1ec` | struct | `21432944` | `eqID` @ `0x1015d749c`; `volValue` @ `0x1015d74a1`; `volLevel` @ `0x1015d74aa` |
| `HearingProtectionStatus` @ `0x1015ab208` | struct | `21432976` | `type` @ `0x1015d74b3`; `status` @ `0x1015d74b8`; `attribute` @ `0x1015d74bf` |
| `HearingSenseSyncState` @ `0x1015a0e74` | enum | `21344704` | `ready` @ `0x1015cf330`; `unknown` @ `0x1015cf336`; `syncing` @ `0x1015cf33e` |
| `DetectState` @ `0x1015a4e00` | enum | `21378792` | `end` @ `0x1015d1927`; `toStart` @ `0x1015d192b`; `detecting` @ `0x1015d1933`; `abnormal` @ `0x1015d193d`; `noNetwork` @ `0x1015d1946` |

## Dual connection

The generic dual-device record distinguishes connection, currently active phone, main device, playback, and category. Priority identities exist in the app, but Buds 4 fallback omits `priorityDevice`; do not promise that UI or infer its command format.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `DuplexDevice` @ `0x10159067c` | struct | `21177322` | `address` @ `0x1015b6404`; `connectedState` @ `0x1015b640c`; `currentPhone` @ `0x1015b641b`; `name` @ `0x1015b6428`; `isMainDevice` @ `0x1015b642d`; `isPlaying` @ `0x1015b643a`; `catetory` @ `0x1015b6444` |
| `ConnectedState` @ `0x101590698` | enum | `21177335` | `disconnected` @ `0x1015b644d`; `connecting` @ `0x1015b645a`; `connected` @ `0x1015b6465` |
| `DuplexPriorityItem` @ `0x1015907e8` | struct | `21178192` | `id` @ `0x1015b6490`; `name` @ `0x1015b6428`; `select` @ `0x1015b6493`; `mac` @ `0x1015b649a`; `category` @ `0x1015b649e`; `connected` @ `0x1015b6465` |
| `DuplexModel` @ `0x10158a8b0` | class | `21113530` | `_isOn` @ `0x1015afa00`; `_duplexDevices` @ `0x1015afa06`; `_isDisconnected` @ `0x1015afa15`; `_editMode` @ `0x1015afa25`; `_priorityItems` @ `0x1015afa2f`; `$__lazy_storage_$_isReboot` @ `0x1015afa40`; `userDefaults` @ `0x1015afa5b`; `$__lazy_storage_$_priorityDevice` @ `0x1015afa70`; `setPriorityDevice` @ `0x1015afaa0` |
| `SetDeviceDualOperationType` @ `0x1015a03e0` | enum | `21336784` | `connect` @ `0x1015ceacb`; `disconnect` @ `0x1015cead3`; `cancelPaired` @ `0x1015ceade`; `priority` @ `0x1015ceaeb` |
| `ConnectedDeviceInfo` @ `0x1015a99e0` | struct | `21418768` | `connectedType` @ `0x1015d5714`; `deviceAddrId` @ `0x1015d5722`; `deviceNameId` @ `0x1015d572f`; `count` @ `0x1015d573c` |
| `DuplexToastType` @ `0x10158a894` | enum | `21113514` | `timeout` @ `0x1015af9e0`; `failure` @ `0x1015af9e8`; `connectedDevice` @ `0x1015af9f0` |

## Errors and connection/request/firmware states

Error/state cases must remain separate from raw device status bytes until decoder/raw-value code is traced. Some generic `State` identities are unresolved as to enclosing owner. `AppendixDErrorCode` names are exact reflected cases, not a numbered error-code table.

| Type identity / descriptor | Kind | Type-name file offset | Exact reflected fields/cases and preferred addresses |
| --- | --- | --- | --- |
| `BTDataError` @ `0x10159e6e8` | enum | `21322898` | `timeout` @ `0x1015cd7b0`; `peripheralNil` @ `0x1015cd7b8`; `writeCharacteristicNil` @ `0x1015cd7d0` |
| `BTTaskError` @ `0x1015a951c` | enum | `21418010` | `timeOut` @ `0x1015d5580`; `connection` @ `0x1015d5588`; `retryFailed` @ `0x1015d5593`; `bluetoothPowerOff` @ `0x1015d55a0`; `userCancelled` @ `0x1015d55b2` |
| `AppendixDErrorCode` @ `0x1015aa654` | enum | `21422560` | `success` @ `0x1015d5dd0`; `failure` @ `0x1015d5dd8`; `invalidParameter` @ `0x1015d5de0`; `verificationFailure` @ `0x1015d5e00`; `validationFailure` @ `0x1015d5e20`; `timeoutWithoutAck` @ `0x1015d5e40`; `timeout` @ `0x1015d5e52`; `writtingFailure` @ `0x1015d5e5a`; `failureDueToPlayMusic` @ `0x1015d5e70`; `failureDueToCall` @ `0x1015d5e90`; `disconnectBetweenTwoEarphones` @ `0x1015d5eb0`; `doNotWearEarphones` @ `0x1015d5ed0`; `versionErrorBetweenTwoEarphones` @ `0x1015d5ef0`; `failureDueToNoise` @ `0x1015d5f10`; `doNotWearAnyEarphones` @ `0x1015d5f30`; `duringProcess` @ `0x1015d5f46`; `lowBattery` @ `0x1015d5f54`; `failureToRetry` @ `0x1015d5f5f`; `earbudIsBusy` @ `0x1015d5f6e`; `failureToRetryWithOffset` @ `0x1015d5f80`; `failureForOutBox` @ `0x1015d5fa0`; `userCancelled` @ `0x1015d5fb1` |
| `EarbudFunctionError` @ `0x1015a22c4` | enum | `21356208` | `batteryError` @ `0x1015d0100`; `remoteVersionError` @ `0x1015d0110` |
| `EarbudRequestQueueCancelled` @ `0x10159519c` | struct | `21225168` | (none reflected) |
| `Status` @ `0x101597e94` | enum | `21247744` | `success` @ `0x1015c8895`; `failure` @ `0x1015c889d`; `none` @ `0x1015c88a5`; `waitingForResponse` @ `0x1015c88b0` |
| `BluetoothScanState` @ `0x1015a47a0` | enum | `21377184` | `scannedPeripheral` @ `0x1015d14b0`; `notStartScan` @ `0x1015d14c2`; `startScan` @ `0x1015d14cf`; `noPeripheralBroadcasting` @ `0x1015d14e0`; `scanTimeout` @ `0x1015d14f9` |
| `BluetoothConnectState` @ `0x1015a47bc` | enum | `21377216` | `gattConnectSuccess` @ `0x1015d1510`; `connectFailed` @ `0x1015d1523`; `unsupportCTKDDeviceSelected` @ `0x1015d1540`; `startConnectInPairDevice` @ `0x1015d1560`; `routeAddressChanged` @ `0x1015d1580` |
| `PairState` @ `0x1015a6548` | enum | `21385992` | `notInPairing` @ `0x1015d2ba7`; `inPairing` @ `0x1015d2bb4`; `connected` @ `0x1015d2bbe`; `backConnectNoInPairing` @ `0x1015d2bd0` |
| `ConnectStatus` @ `0x1015a1f70` | enum | `21349664` | `connected` @ `0x1015cff90`; `connecting` @ `0x1015cff9a`; `failure` @ `0x1015cffa5` |
| `DeviceConnectStatus` @ `0x1015a0dec` | enum | `21344448` | `success` @ `0x1015cf2d0`; `historyConneting` @ `0x1015cf2e0`; `disconnected` @ `0x1015cf2f1`; `none` @ `0x1015cf2fe` |
| `OTAUpgradeState` @ `0x10158aa74` | enum | `21113858` | `failure` @ `0x1015afaf0`; `upgrading` @ `0x1015afaf8`; `success` @ `0x1015afb02` |
| `FirmwareUpdateStatus` @ `0x10158e6a4` | enum | `21147680` | `none` @ `0x1015b3f40`; `found` @ `0x1015b3f45`; `downloading` @ `0x1015b3f4b`; `transporting` @ `0x1015b3f57`; `installing` @ `0x1015b3f64`; `success` @ `0x1015b3f6f`; `failure` @ `0x1015b3f77`; `timeout` @ `0x1015b3f7f` |
| `UploadError` @ `0x10158e230` | enum | `21145912` | `otaFailure` @ `0x1015b3b30`; `noToneData` @ `0x1015b3b3b`; `noHeadset` @ `0x1015b3b46`; `disconnected` @ `0x1015b3b50`; `oneEarbudDisconnected` @ `0x1015b3b60` |
| `OTABlockVerifyError` @ `0x10159a838` | struct | `21274640` | `errorCode` @ `0x1015ca1d0`; `retryStartOffset` @ `0x1015ca1e0` |
| `State` @ `0x10158adb4` | enum | `21114165` | `error` @ `0x1015afcb9`; `waiting` @ `0x1015afcbf`; `send` @ `0x1015afcc7`; `check` @ `0x1015afccc`; `complete` @ `0x1015afcd2` |
| `State` @ `0x1015a9f08` | enum | `21419717` | `waiting` @ `0x1015d5a52`; `send` @ `0x1015d5a5a`; `check` @ `0x1015d5a5f`; `error` @ `0x1015d5a65`; `complete` @ `0x1015d5a6b` |
| `State` @ `0x1015a9fe4` | enum | `21419717` | `waiting` @ `0x1015d5a52`; `clean` @ `0x1015d5a9d`; `success` @ `0x1015d598a`; `failure` @ `0x1015d5992` |

## Decoder identities and missing value schemas

The native index separately records decoder structs, each with reflected `contentData`: `BatteryDecoder`, `PeripheralEarbudsStatusDecoder`, `PeripheralNoiseReductionInfoDecoder`, `FunctionKeyDecoder`, `PeripheralFeatureStatusDecoder`, `EQIDDecoder`, `CustomEQDecoder`, `HearingTestResultDecoder`, `CompactnessDetectDecoder`, `EarScanTestResultDecoder`, `EarScanFilterDecoder`, `DuplexDeviceDecoder`, `SpatialAudioDecoder`, and `HeadGestureControlDecoder`. Their names do not prove return-type relationships to the structures above. Exact descriptor and field addresses are in the native index.

Still needed from code: each decoder's minimum length, indexing, conversions and error/sentinel handling; each setter's serialization and acknowledgment; poll versus event payload differences; capability gates; shared/common versus model-specific version checks; and persistence/cloud schema dependencies. The root protocol investigation should supply these separately before any implementation.

## Semantic dependencies to verify

| Target flow | Evidence-backed identities to trace together | Remaining dependency question |
| --- | --- | --- |
| Dashboard and reconnect | Battery, wearing, connection, and capability types | Which values are refreshed together, which stale values are cleared, and what marks a usable session? |
| ANC / adaptive / transparency / off | Noise action/type/value and per-ear state | Which supported options are device-reported and which fallback modes/levels are valid for Buds 4? |
| EQ / custom curve / bass | Preset, custom EQ, version, bass and mutex types | Which adjustments coexist, what limits apply, and how does device-confirmed state replace UI edits? |
| Per-ear media/noise/call controls | Ear, button, action, function and support types | Which contexts change available functions and the serialization of a left/right mapping? |
| Golden Sound / fit | Wearing, compactness, test, ear scan, filter, saved record and interruption types | Which acoustic/test steps, results and saved attributes must be complete before audition/apply? |
| OnePlus 3D Audio | Spatial sound plus generic spatial mode/gate identities | Is target control a feature switch, a spatial-mode payload, host rendering, or a combination? |
| Dual connection | Feature switch, duplex device/state and operation types | Which actions reboot/disconnect the control session, and does Buds 4 expose priority management? |
| Error/retry/firmware UI | Request and device error families, connection and firmware state | Which failures are transient, resumable, terminal, or user cancellation? |

The trace groupings above are an investigation plan, not proven native call relationships. No packet command or device mutation is authorized or implemented by this document.
