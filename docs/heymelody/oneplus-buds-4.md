# OnePlus Buds 4: focused target profile

User-selected target: **OnePlus Buds 4**. This profile narrows the reconstruction target while preserving the broader multi-model inventory. Evidence is static packaged configuration; the physical earbuds and their firmware have not been accessed or modified.

User deployment target: **macOS + Chrome**. The user-supplied About Earbuds screenshot shows firmware **138.138.105** and “Version up to date”; see [USER-001](evidence/user-environment.json) and [retained screenshot](evidence/user-firmware-screen.png). The crop does not show the model name, so its association with Buds 4 comes from the conversation. OS/browser versions and current vendor catalog status were not independently checked.

## Exact match and provenance

[RES-010: focused raw profile](evidence/oneplus-buds-4-profile.json) is a lossless selection from [RES-004: bundled whitelist](evidence/device-whitelist.json). Exactly one record matches name `OnePlus Buds 4` and model ID `065414` (six-character hexadecimal-looking string; its binary encoding is not proved by this resource). The selection is `whiteList[58]` with zero-based indexing. Source: `/Applications/HeyMelody.app/Wrapper/HeyMelody.app/whitelist_default_external_release.headset`; source SHA-256 is retained in RES-004 and RES-010. App 2.30.0 metadata and capability parsing are in RES-003 and RES-005.

Observed identity/connection fields: `mark="开普勒(OnePlus)"`, `alias=true`, `brand="OnePlus"`, `type="T1"`, `uuid="0000079A-D102-11E1-9B23-00025B00A5A5"`, `minRiss=-70`, `minVersion=0`, `newMinVersion="2.11.1"`, `checkResponse=true`, `ctkd=1`, `gattV2=1`. The `isHidden` and `otaCategory` fields are absent. Empty `headsetAdditional={}` and function `additional={}` are preserved.

The UUID and GATT/CTKD flags are transport candidates that need code-path confirmation. They do not alone establish a browser-accessible service, an authentication method, cross-transport pairing behavior, characteristic UUIDs or a successful connection. The name `minRiss` is preserved as shipped; interpreting it as an RSSI threshold is an inference until the consumer code is traced. `newMinVersion` is an apparent minimum app-version gate; exact comparison behavior is unknown here.

## Expected target UI, reconciled against global features

| Feature/page | Target configuration evidence | Expected reconstruction and boundary |
|---|---|---|
| Connected dashboard / battery | Identity, wear flags, scan/list/battery UI resources | Dashboard with left/right/case and connection states is expected; actual dashboard order/layout, charging-state encoding and case timing require code/passive UI evidence. |
| Noise control | `showDenoiseSwitch=1`, category 4, `getDenoiseOptopnsFromHeadset=1`, four named modes | Expected ANC, Adaptive, Transparency, Off; dynamic earbud options should override fallback where code does so. Category 4 and mode-wire mapping remain unresolved. Long-press noise-cycle config allows at least one selected mode (`longTapNoiseReductionMinItems=1`), unlike some newer models' minimum two. |
| Sound presets / custom EQ / bass | Three preset records; `customEQ=1`, `bassEngine=1`, `equalizer=0` | Expected preset and custom EQ controls plus bass feature. Preset IDs are 0 Balanced (Default), 1 Serenade, 2 Bass using RES-002 strings. `equalizer=0` cannot mean “no EQ”: explicit preset records and tutorial copy contradict that naive interpretation. Exact category, bands, gains, custom limits and sharing support need code. |
| OnePlus 3D Audio | `spatialSound=2`, tutorial key `spatialSoundOnePlus` | Expected OnePlus 3D Audio page/toggle; no `spatialAudio` field appears. Do not assume a head-tracking mode merely from the app's generic Spatial Audio copy. Fixed/tracking options need device/code confirmation. |
| Golden Sound | `goldenHearingSense=1`, `compact=1` | Expected fit test and Golden Sound hearing/ear-canal flow, saved scheme/history and audition/apply. Legacy NIB yes/no hearing test is not proof that this target uses that exact interaction; global Golden Sound slider copy may select a newer flow. |
| Earbud controls and tutorials | Seven raw control entries; `controlGuiding=true`, `funcIntro=true` | Expected per-ear media/assistant/game/volume/noise control bindings and call controls. Tutor variants are preserved below. Gesture names inferred for undescribed action numbers must be confirmed in code. |
| Dual connection | `duplex=1`, dual-connection tutorial | Expected dual-device toggle and connected-device state; no `priorityDevice` field here, so prefer-device UI is not positively established by fallback. |
| Game mode | `showGameMode=1`, control function 8192, `gameEffect=0` | Expected low-latency game mode. `gameEffect=0` does not negate `showGameMode=1`; enhanced gaming effect and low-latency mode appear to be distinct concepts. Exact semantics need code. |
| Wearing/auto pause | `inEarDetection=[0]`, `wearCheck=1`, `wearStatus=1` | Expected wearing state and likely smart pause/resume. Array member 0 and selection defaults need enum decode; generic copy does not prove exact behavior. |
| Locate earbuds | `findDevice=1` | Expected find function with case/wearing/call restrictions; no find command was sent. |
| Firmware and diagnostics | `ota=1`, `otaMinBattery=30`, `headsetLog=1`, `maintain=1` | Expected update status/progress and support/log capabilities. Threshold is raw config (unit inferred as battery percent). `maintain=1` meaning and log UI gating unresolved. No update/download/log/device operation occurred. |
| Prompt tone/theme | `personalizedTone=1`, `promptVolCtrl=1` | Expected tone personalization or tone-volume controls; exact variants, resource requirements, popup/themes/carousels reachability on this iOS-on-Mac build remain unproved. |
| Voice Assistant / AI translation | `aiPlayOrPause=1`, voice-assistant control candidate 1; assistant tutorial | Positive evidence for assistant-related earbud controls. **Translation eligibility is unresolved**: no explicit translation field exists; `aiPlayOrPause=1` must not be relabeled “translation supported” without consumer-code proof. Global translation UI can be documented without promising target eligibility or vendor-service reuse. |
| Personalized ANC | `personalizeDenoise=0` | Fallback does not positively advertise a personalized-ANC test, though normal fit/Golden Sound exist. Zero meaning still requires code. |
| Neck health / voice commands / head gestures / sleep pause | No `neckHealth`, `voiceQuickCommand`, explicit head-gesture or sleep fields | No positive fallback evidence of these features for Buds 4. The generic app contains their copy; two other hidden models explicitly enable neck health. Missing fields cannot exclude firmware/server-driven support, and switch-status values could gate additional features. |
| White noise / Zen Mode Air | No `whiteNoise`, `chanDing`, `sound` fields | No positive fallback evidence of standalone earbud sound transfer or Zen Mode Air for this target. A host-only Sound space may still exist independently; reachability is unresolved. |
| Conversation awareness / adaptive audio / fall detection / high-res | No named fields establishing these functions; `switchStatus` list exists | Do not expose these solely because generic localization is present. Native switch-status mapping and actual capability responses are required. |

## All scalar/array capabilities, exactly as bundled

No value below has been coerced to Boolean or translated into a wire opcode. Numeric category semantics, switch codes, defaults and firmware conditions remain unknown unless separate native evidence establishes them.

| Function field | Raw value |
|---|---|
| `additional` | `{}` |
| `aiPlayOrPause` | `1` |
| `bassEngine` | `1` |
| `compact` | `1` |
| `controlGuiding` | `true` |
| `customEQ` | `1` |
| `duplex` | `1` |
| `equalizer` | `0` |
| `findDevice` | `1` |
| `funcIntro` | `true` |
| `gameEffect` | `0` |
| `getDenoiseOptopnsFromHeadset` | `1` |
| `goldenHearingSense` | `1` |
| `headsetLog` | `1` |
| `inEarDetection` | `[0]` |
| `maintain` | `1` |
| `noiseReductionCategory` | `4` |
| `ota` | `1` |
| `otaMinBattery` | `30` |
| `pairedKey` | `1` |
| `personalizeDenoise` | `0` |
| `personalizedTone` | `1` |
| `promptVolCtrl` | `1` |
| `ratingPriority` | `2` |
| `showDenoiseSwitch` | `1` |
| `showGameMode` | `1` |
| `spatialSound` | `2` |
| `supportNoiseReductions` | `["reduction", "adaptive", "transparent", "close"]` |
| `switchStatus` | `[4, 11, 6, 9, 12, 15, 17, 30]` |
| `wearCheck` | `1` |
| `wearStatus` | `1` |
| `longTapNoiseReductionMinItems` | `1` |

## Controls and candidate meanings

Every target entry has `ear=2` and `showEar=1`; meanings of those enum values need consumer-code confirmation. The following English descriptions are translations of the shipped Chinese `supportFunction` strings, **not established packet commands**. IDs are kept in source order. `button=6` appears only for the two explicitly described call controls.

| Action raw | Support IDs raw | Shipped description translated | Additional raw metadata |
|---|---|---|---|
| 1 | `[512,4]` | None; play/pause | No `actionDesc`; candidate single tap/pinch must be confirmed. |
| 2 | `[512,4,32,64,1,8192]` | None; play/pause; previous; next; voice assistant; game mode | No `actionDesc`; candidate double tap/pinch. |
| 3 | `[512,32,64,1,8192]` | None; previous; next; voice assistant; game mode | No `actionDesc`; candidate triple tap/pinch. |
| 5 | `[512,1024,2048]` | None; adjust volume; switch songs | `showsub=true`; candidate swipe. |
| 4 | `[512,128]` | None; switch noise cancellation | Candidate hold/pinch-and-hold. |
| 2 | `[512,17]` | None; answer/end call | `actionDesc="双击"` (double tap), `button=6`. |
| 6 | `[512,18]` | None; reject incoming call | `actionDesc="超长按"` (extra-long hold), `button=6`. |

The candidate function map from the parallel raw number/text lists is: 512 none; 4 play/pause; 32 previous; 64 next; 1 assistant; 8192 game mode; 1024 volume adjustment; 2048 song switching; 128 noise switching; 17 answer/end; 18 reject. This is a **configuration-semantic inference**, not proof that these numbers occur unmodified in Bluetooth packets or of their width/endianness. Several values look like bit flags, but 17/18 show why treating the entire set as independent flags would be unsafe.

## Tutorials and presets

`equalizerInfo.title="none"`; presets `{id:0,name:"balancedEQ"}`, `{id:1,name:"pureVoiceEQ"}`, `{id:2,name:"deepBassEQ"}`. English names are Balanced (Default), Serenade and Bass (RES-002). Target presets are different from other models' numbering; never copy another model's EQ IDs.

`tutorialGuideFunctionsV2` contains master EQ (id 1), OnePlus 3D Audio (id 0), noise control (id 2), dual connection (id 3). `tutorialGuideIntro` duplicates those four under `minAppVersion="2.15.0"`. `tutorialGuideIntroV2` has the same apparent minimum and adds Voice Assistant (id 4) before dual connection. All localization/icon keys and nested structures are preserved in the full raw record below. The presence of two intro variants does not establish which variant this build selects or whether both appear.

The OnePlus 3D Audio tutorial copy says spatial audio on phones and earbuds is supported; that statement does not reveal whether rendering is host- or earbud-side for each mode. Noise tutorial explicitly describes Adaptive blending ANC and Transparency.

## Enum and live-state gaps for this target

- `switchStatus=[4,11,6,9,12,15,17,30]`: resources alone do not establish meanings. [Feature values](feature-values.md) now maps code-derived numbers and ABI-correlated names, but the configuration consumer and eligibility semantics remain unresolved. Do not promise extra toggles from this list.
- `type=T1`, `gattV2=1`, `ctkd=1`, `checkResponse=true`, alias behavior, identity/matching byte order, packet transport and handshake require Ghidra/native confirmation. Pairing state on the user's host is unknown.
- `noiseReductionCategory=4`, `customEQ=1`, `duplex=1`, `spatialSound=2`, `gameEffect=0`, `equalizer=0`, `aiPlayOrPause=1`, `personalizedTone=1`, `ratingPriority=2`, `pairedKey=1`, `inEarDetection=[0]` are unparsed enums/categories at this resource layer. Treating every nonzero field as enabled or zero as absent creates contradictions in this record.
- Firmware version 138.138.105 is user-supplied evidence. Color, vendor/product IDs, service advertisement, characteristic properties, MTU, negotiated protocol version, device feature report, regional/cloud/account gates and firmware-update prerequisites are unknown without further evidence.
- Generic UI text is not target eligibility proof. Missing capability fields may mean defaults, lack of support, server update or runtime negotiation; static absence alone cannot choose between them.

This is an investigation artifact. [parse_resources.py](evidence/parse_resources.py) only reads installed package files and writes parsed research evidence; it does not implement a web app, bridge, Bluetooth client or protocol, and cannot connect to or modify earbuds. No implementation has been built.

## Complete selected record

This is the entire exact parsed JSON record after trailing-comma removal; names, enum values, list order, empty dictionaries and absent optional fields remain faithful to the shipped resource.

```json
{
  "id": "065414",
  "name": "OnePlus Buds 4",
  "mark": "开普勒(OnePlus)",
  "alias": true,
  "brand": "OnePlus",
  "type": "T1",
  "uuid": "0000079A-D102-11E1-9B23-00025B00A5A5",
  "minRiss": -70,
  "minVersion": 0,
  "newMinVersion": "2.11.1",
  "checkResponse": true,
  "ctkd": 1,
  "gattV2": 1,
  "function": {
    "additional": {},
    "aiPlayOrPause": 1,
    "bassEngine": 1,
    "compact": 1,
    "control": [
      {
        "ear": 2,
        "support": [
          512,
          4
        ],
        "supportFunction": "无、播放/暂停",
        "showEar": 1,
        "action": 1
      },
      {
        "ear": 2,
        "support": [
          512,
          4,
          32,
          64,
          1,
          8192
        ],
        "supportFunction": "无、播放/暂停、上一首、下一首、语音助手、 游戏模式",
        "showEar": 1,
        "action": 2
      },
      {
        "ear": 2,
        "support": [
          512,
          32,
          64,
          1,
          8192
        ],
        "supportFunction": "无、上一曲、下一曲、语音助手、游戏模式",
        "showEar": 1,
        "action": 3
      },
      {
        "ear": 2,
        "support": [
          512,
          1024,
          2048
        ],
        "supportFunction": "无、调节音量、切换歌曲",
        "showEar": 1,
        "showsub": true,
        "action": 5
      },
      {
        "ear": 2,
        "support": [
          512,
          128
        ],
        "supportFunction": "无、切换降噪",
        "showEar": 1,
        "action": 4
      },
      {
        "ear": 2,
        "support": [
          512,
          17
        ],
        "supportFunction": "无、接听/挂断电话",
        "showEar": 1,
        "action": 2,
        "actionDesc": "双击",
        "button": 6
      },
      {
        "ear": 2,
        "support": [
          512,
          18
        ],
        "supportFunction": "无、拒绝来电",
        "showEar": 1,
        "action": 6,
        "actionDesc": "超长按",
        "button": 6
      }
    ],
    "controlGuiding": true,
    "customEQ": 1,
    "duplex": 1,
    "equalizer": 0,
    "equalizerInfo": {
      "title": "none",
      "types": [
        {
          "id": 0,
          "name": "balancedEQ"
        },
        {
          "id": 1,
          "name": "pureVoiceEQ"
        },
        {
          "id": 2,
          "name": "deepBassEQ"
        }
      ]
    },
    "findDevice": 1,
    "funcIntro": true,
    "gameEffect": 0,
    "getDenoiseOptopnsFromHeadset": 1,
    "goldenHearingSense": 1,
    "headsetLog": 1,
    "inEarDetection": [
      0
    ],
    "maintain": 1,
    "noiseReductionCategory": 4,
    "ota": 1,
    "otaMinBattery": 30,
    "pairedKey": 1,
    "personalizeDenoise": 0,
    "personalizedTone": 1,
    "promptVolCtrl": 1,
    "ratingPriority": 2,
    "showDenoiseSwitch": 1,
    "showGameMode": 1,
    "spatialSound": 2,
    "supportNoiseReductions": [
      "reduction",
      "adaptive",
      "transparent",
      "close"
    ],
    "switchStatus": [
      4,
      11,
      6,
      9,
      12,
      15,
      17,
      30
    ],
    "tutorialGuideFunctionsV2": [
      {
        "id": 1,
        "title": "tutorialGuide_masterEQ_title",
        "subtitle": "tutorialGuide_masterEQ_message1",
        "icon": "tutorialGuide_masterEQ_icon"
      },
      {
        "id": 0,
        "title": "spatialSoundOnePlus",
        "subtitle": "tutorialGuide_spatialAudio_subtitle_v1",
        "icon": "tutorialGuide_spatialAudio_icon"
      },
      {
        "id": 2,
        "title": "noiseControl",
        "subtitle": "tutorialGuide_noiseReduce_subtitle2",
        "icon": "tutorialGuide_noiseReduce_icon"
      },
      {
        "id": 3,
        "title": "tutorialGuide_duplex_title",
        "subtitle": "tutorialGuide_duplex_subtitle",
        "icon": "tutorialGuide_duplex_icon"
      }
    ],
    "tutorialGuideIntro": {
      "minAppVersion": "2.15.0",
      "funcs": [
        {
          "id": 1,
          "title": "tutorialGuide_masterEQ_title",
          "subtitle": "tutorialGuide_masterEQ_message1",
          "icon": "tutorialGuide_masterEQ_icon"
        },
        {
          "id": 0,
          "title": "spatialSoundOnePlus",
          "subtitle": "tutorialGuide_spatialAudio_subtitle_v1",
          "icon": "tutorialGuide_spatialAudio_icon"
        },
        {
          "id": 2,
          "title": "noiseControl",
          "subtitle": "tutorialGuide_noiseReduce_subtitle2",
          "icon": "tutorialGuide_noiseReduce_icon"
        },
        {
          "id": 3,
          "title": "tutorialGuide_duplex_title",
          "subtitle": "tutorialGuide_duplex_subtitle",
          "icon": "tutorialGuide_duplex_icon"
        }
      ]
    },
    "tutorialGuideIntroV2": {
      "minAppVersion": "2.15.0",
      "funcs": [
        {
          "id": 1,
          "title": "tutorialGuide_masterEQ_title",
          "subtitle": "tutorialGuide_masterEQ_message1",
          "icon": "tutorialGuide_masterEQ_icon"
        },
        {
          "id": 0,
          "title": "spatialSoundOnePlus",
          "subtitle": "tutorialGuide_spatialAudio_subtitle_v1",
          "icon": "tutorialGuide_spatialAudio_icon"
        },
        {
          "id": 2,
          "title": "noiseControl",
          "subtitle": "tutorialGuide_noiseReduce_subtitle2",
          "icon": "tutorialGuide_noiseReduce_icon"
        },
        {
          "id": 4,
          "title": "wakeupAssistant",
          "subtitle": "tutorialGuide_wakeupAssistant_subtitle",
          "icon": "tutorialGuide_wakeupAssistant_icon"
        },
        {
          "id": 3,
          "title": "tutorialGuide_duplex_title",
          "subtitle": "tutorialGuide_duplex_subtitle",
          "icon": "tutorialGuide_duplex_icon"
        }
      ]
    },
    "wearCheck": 1,
    "wearStatus": 1,
    "longTapNoiseReductionMinItems": 1
  },
  "headsetAdditional": {}
}
```

## Subsequent hardware and build status

The statements above describe their original investigation phase. [Extended read-only validation](feature-validation.md) now directly confirms firmware 138.138.105, model 065414, inventory queries, live battery/wearing/noise events and one reconnect on macOS/Chrome. The first read-only dashboard is implemented and user-confirmed. Web Bluetooth GATT, setting changes and advanced-feature parity remain unvalidated.
