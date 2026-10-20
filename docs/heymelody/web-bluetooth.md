# Browser transport feasibility

Investigated: 2026-10-12. Scope: primary browser specifications, browser vendor documentation, and compatibility-source data. No earbud discovery, connection, pairing, reads, writes, or firmware changes were performed.

**Conclusion:** an app-equivalent web UI is feasible, but direct device control depends on the actual service exposed by the selected earbud model. Web Bluetooth can carry a compatible GATT control protocol. BLE GATT and GATT over BR/EDR require separate feasibility checks. A separate, potentially useful direct route is desktop Chrome's Web Serial support for paired classic Bluetooth RFCOMM services; RFCOMM cannot substitute for GATT over BR/EDR. A native bridge is required where the necessary transport or platform operation is unavailable to the browser. No browser source below establishes which transport HeyMelody actually uses.

## Evidence classification

Authorized runtime follow-up: [transport-validation.md](transport-validation.md) establishes direct Chrome/macOS Web Serial custom-service access. The port opened with readable/writable streams and received data without outbound commands. The original browser feasibility tables remain general; this target now has concrete connection-level evidence.

Follow-up source review: [QuickBuds](quickbuds-reference.md) implements custom-service RFCOMM and reports testing Buds 4 firmware 138.138.105. Its `079A` UUID provides a concrete Web Serial candidate; prioritize that eligibility check alongside GATT. This is author-reported testing on Android/Windows/Linux, not validation on the user's Mac.

- **Browser fact:** backed by the references below.
- **Conditional feasibility:** follows from those browser facts only if artifact/device investigation confirms the stated earbud capability.
- **Recommendation:** proposed implementation design, not an observed HeyMelody behavior.
- **Unknown:** must be resolved from the app and, later, a user-authorized investigation of the identified earbud model.

The feature examples below are transport categories, not a claim that every listed feature exists in this HeyMelody build or on every supported earbud.

## Browser facts

| ID | Finding | Evidence |
| --- | --- | --- |
| WB-01 | Web Bluetooth exposes GATT service/characteristic discovery, reads, writes, and notification subscriptions. It is not an API for opening arbitrary classic Bluetooth RFCOMM channels or controlling the Bluetooth audio stack. | Chrome's Bluetooth documentation explicitly directs classic RFCOMM users to Web Serial; the Web Bluetooth interface specifies GATT operations. [S1], [S2], [S3] |
| WB-02 | Initial device selection requires a user gesture and a secure context. The chooser grants access to specific devices/services; a web application cannot silently take unrestricted Bluetooth access. | [S1], [S2] |
| WB-03 | Services omitted from the service filter must be named in `optionalServices` before they can be accessed. Selecting by device name does not by itself authorize all services. | [S1] |
| WB-04 | Service/characteristic blocklists impose additional restrictions that user consent cannot remove. Examples include standard HID service `1812`, Nordic legacy DFU `00001530-1212-efde-1523-785feabcd123`, TI OAD `f000ffc0-0451-4000-b000-000000000000`, and Cypress bootloader `00060000-0000-1000-8000-00805f9b34fb`. Standard serial-number characteristic `2a25` is blocked; CCCD `2902` writes are blocked. This does **not** mean every vendor firmware service is blocked. | Published registry, pinned to its latest file-changing commit at retrieval. [S4] |
| WB-05 | Subscribe with `startNotifications()` and process `characteristicvaluechanged`. Use `writeValueWithResponse()` or `writeValueWithoutResponse()` according to the characteristic and protocol. Deprecated `writeValue()` is unsuitable as the new implementation's default. | [S1], [S2] |
| WB-06 | The specification rejects characteristic values larger than 512 bytes. This is an attribute-value ceiling, **not** a guarantee that 512-byte writes work on a particular earbud or write mode. The user agent negotiates MTU internally; the published JS API exposes no MTU setter/getter. | Specification's characteristic-write algorithm, connection algorithm, and interface definitions. [S2] |
| WB-07 | Concurrent GATT operations can fail depending on the platform. Chrome's guidance recommends queuing operations. | [S1] |
| WB-08 | Web Bluetooth is a `Window` API in the specification, not a Bluetooth worker/service-worker API. The specification includes a `bluetooth` Permissions Policy integration. | [S2] |
| WB-09 | Since Chrome 117 on desktop, Web Serial supports RFCOMM on already paired classic Bluetooth devices, including SPP. It can expose services even where the OS has not created a conventional serial-device node. | [S3] |
| WB-10 | Nonstandard RFCOMM service-class UUIDs can be permitted through `allowedBluetoothServiceClassIds` and selected through `bluetoothServiceClassId`. Chrome blocks service-class UUIDs using the SIG base UUID suffix `-0000-1000-8000-00805f9b34fb` except the Serial Port Profile ID. It does not expose classic audio/video services through this path. | [S3] |
| WB-11 | Browser audio-output selection operates on OS-provided audio-device IDs through APIs such as `setSinkId()` and `selectAudioOutput()`. It does not configure the earbud's A2DP/HFP/LE Audio pairing, codec, or profile. | Audio Output Devices specification defines selection of an existing output device; the transport APIs above do not expose Bluetooth audio-profile configuration. [S2], [S3], [S7] |
| WB-12 | A hosted page connecting to a local bridge must account for browser local-network security. Chrome's documented Local Network Access permission launched in version 142; its coverage and exceptions are evolving. Do not assume that a localhost endpoint is automatically accessible without browser-policy work. | [S8] |

## GATT over BR/EDR and CTKD: separate feasibility gate

OnePlus Buds 4 is now the investigation target. Its resource profile has `gattV2=1` and `ctkd=1`, and the native artifact contains explicit GATT-over-EDR diagnostic strings, `getGATTOverEdrState`, and native transport-bridging/connection-event imports. These observations do not by themselves prove the active transport on the user's hardware. See [architecture.md](architecture.md) and [oneplus-buds-4.md](oneplus-buds-4.md).

**What primary sources establish:**

- Apple explicitly documents CoreBluetooth support for GATT over BR/EDR: WWDC 2019 session 901, approximately 09:11–11:20, describes using the same peripheral GATT APIs for classic devices. Its sample identifies iOS 13 and Mac Catalyst support. This establishes native API capability on the documented platforms, not browser support on this Mac. [S9]
- Chromium's current Web Bluetooth chooser explicitly configures an **LE discovery filter** and explains that general dual scanning would present devices the API cannot use. Consequently, classic-only inquiry/discovery is not a supported parity assumption. The same chooser initially populates already known GATT-connected devices from its adapter and retains a TODO about retrieving further connected devices. [S11]
- Chromium's Apple adapter separately implements retrieval of existing CoreBluetooth peripherals by service UUID via `retrieveConnectedPeripheralsWithServices:` and opens its GATT connection with `options:nil`. That implementation shows a possible platform-dependent route; the presence of this adapter method alone does not prove that the Web Bluetooth chooser invokes it for a classic-only Buds 4 connection. The full call chain and shipped browser version require confirmation. [S10], [S11]
- Apple defines `CBConnectPeripheralOptionEnableTransportBridgingKey` as an option for bringing up **non-GATT classic profiles** when a low-energy GATT connection exists. It should not be described as an RFCOMM endpoint or a generic switch that directly makes browser GATT-over-BR/EDR work. The web GATT API does not expose that native connection-options dictionary. [S2], [S12]

**Decision:** do not categorically claim that Web Bluetooth can never reach classic GATT, and do not promise that it can. Treat GATT-over-BR/EDR browser access as an unresolved platform-specific gate. A successful native app connection, or Safari's ability to use native CoreBluetooth through a companion, does not prove direct web support. Desktop Web Serial helps only if an independent, accessible RFCOMM service is actually found. Native CTKD setup, connection-event subscriptions, required transport bridging, or a classic-only peripheral inaccessible through the chooser require a companion/user OS workflow unless a supported direct route is demonstrated.

The future read-only validation should first establish the selected model's service/characteristic roles and native branch behavior from code, then separately test whether an already system-connected device appears in a supported browser chooser and permits the documented GATT reads. No such device/browser test was performed here.

## Platform targets

This table is a planning snapshot, not a tested guarantee. Feature-detect and test the actual released browser/OS combination before declaring it supported.

| Platform/browser | Direct GATT control | Direct RFCOMM control | Planning implication |
| --- | --- | --- | --- |
| Chrome on macOS | Supported Web Bluetooth subset. [S1], [S5] | Documented for desktop Chrome, subject to pairing/service restrictions. [S3] | Best first candidate for this Mac investigation, after the protocol is known. |
| Chrome on Windows | Documented support from Chrome 70 on Windows 10. [S1], [S5] | Documented for desktop Chrome. [S3] | Verify Windows adapter/driver behavior and earbud connection coexistence. |
| Chrome on Android | Documented GATT support; compatibility data records support from Chrome 56. [S1], [S5] | The cited RFCOMM launch is desktop-only; no Android RFCOMM promise is justified by this source. [S3] | BLE is the direct candidate. Classic control requires a separately validated native path. |
| Chrome on ChromeOS | Chrome documents a supported subset. [S1] | Desktop RFCOMM capability must be validated on the target device rather than inferred from OS branding alone. [S3] | Test exact browser/hardware. |
| Chrome on Linux | Chrome documentation and current compatibility data say Web Bluetooth is not enabled by default. [S1], [S5] | Desktop Chrome documentation is insufficient to guarantee every Linux Bluetooth stack/driver combination. [S3] | Do not count a flag-dependent GATT setup as mainstream support. |
| Safari/WebKit on macOS or iOS | Current compatibility data records no support; WebKit lists Web Bluetooth among APIs it declines to implement under its privacy policy. [S5], [S6] | WebKit's same policy also lists Serial API. [S6] | Native bridge/companion required for control in these browsers. An iOS companion would run on iOS; a Mac localhost bridge does not become localhost on an iPhone. |
| Firefox | Current compatibility data records no Web Bluetooth support. [S5] | Not established by the Chrome-specific source. | Treat direct support as unproven; plan a bridge. |
| Edge/other Chromium derivatives | Compatibility data mirrors some Chromium support, but distribution policy and exact platform must be checked. [S5] | Not established merely by Chromium ancestry. | Start with feature detection and an explicit supported-browser list. |

Do not generalize iOS support from desktop Chrome or Android Chrome. Likewise, embedding the site in a WebView does not automatically grant the host's native Bluetooth capabilities; current compatibility data marks Android WebView Web Bluetooth unsupported. [S5]

## Conditional feature matrix

| Capability category | Web Bluetooth | Other direct browser path | When a native bridge is needed |
| --- | --- | --- | --- |
| Static model illustrations, settings UI, onboarding/help, local preferences | No Bluetooth needed. | Ordinary web UI/storage. | No bridge required for the UI itself. |
| Battery, case/left/right status, firmware/model information | Feasible if the values are exposed by authorized, unblocked GATT characteristics or a decodable GATT command channel. | Web Serial if equivalent data is available through accessible RFCOMM. | Proprietary native transport; blocked characteristics; device/platform access unavailable in browser. |
| ANC/transparency, EQ, gesture mappings, game mode, multipoint, and similar device settings | Feasible if the app's commands can be sent through an accessible GATT channel with the correct session/authentication. | Accessible custom RFCOMM is an alternative on supported desktop Chrome. | Required control channel, authentication material, or OS integration is unavailable to the web. |
| Find/ring earbud or any other action that writes to the device | Same conditional transport feasibility as settings. No action was tested here. | Accessible RFCOMM could carry the action. | Depends on actual control channel. These are not read-only validation operations. |
| Hearing/personalization tests and tone playback | Web audio can generate/play tones; GATT can carry the resulting settings only if the device protocol permits it. | OS audio output selection where implemented. [S7] | Native calibration, special audio routing, vendor DSP control, or unavailable device-setting channel. A visually equivalent test is not evidence of acoustically equivalent results. |
| Firmware update | Technically possible only with an unblocked service, understood transfer protocol/authentication, suitable packet sizes and sustained throughput. | Accessible RFCOMM could carry a firmware protocol on desktop. | Blocklisted DFU service, special transfer/native APIs, missing authentication, or required lifecycle/throughput guarantees. Do not classify all firmware updates as bridge-only solely because they update firmware. |
| System Bluetooth pairing/unpairing, audio-profile/codec switching, system-wide audio routing | Not exposed as general Web Bluetooth controls. | Browser audio-device selection only covers an existing output device. [S7] | OS APIs or explicit user action in OS settings. A bridge cannot exceed the OS API's own capabilities. |
| Automatic detection/background reconnection/advertisement-based UX | Do not promise parity. The app must use the browser chooser/permission model and documented implemented features; background scanning is not established by the baseline documentation. [S1], [S2] | Previously granted ports/devices may aid foreground reconnection; still needs platform validation. | Required continuous scanning or persistent background operation is unavailable to the browser. |

Every device-dependent row remains conditional until the app evidence and selected hardware establish the actual endpoint, message schema, handshake, and feature support.

## Recommended transport design

This is a design proposal for the later implementation, not a build performed during this investigation.

1. Put protocol framing, command/response correlation, model capabilities, and normalized device state behind a shared transport-independent core. Keep byte framing independent of Web Bluetooth, RFCOMM streams, and bridge RPC.
2. Offer three possible adapters: **Web Bluetooth GATT**, **desktop Web Serial RFCOMM**, and **native companion bridge**. Enable adapters only after endpoint evidence supports them. If HeyMelody uses a native accessor that the browser cannot express, implement that accessor in the bridge rather than pretending it is GATT.
3. For GATT, make service UUID authorization explicit, subscribe before issuing commands that expect asynchronous responses, serialize operations, distinguish transport acknowledgment from device-level success, and restore discovered characteristic objects/subscriptions after reconnecting.
4. Preserve proven packet boundaries, checksums, sequence numbers, acknowledgment timing, and application fragmentation. Derive safe chunk sizes from native-code evidence and later measured behavior; do not substitute a guessed 20-byte default or the 512-byte attribute ceiling.
5. For RFCOMM, account for byte-stream framing, prior OS pairing, custom service UUID allowance, and partial reads/writes. Confirm that the observed service UUID passes Chrome's restrictions before selecting this as the main path.
6. Have the bridge report its version, OS capabilities, available transports, model identity, and read-only diagnostic status. Keep authorization scoped to the intended site and user-approved device. Bind a desktop bridge to loopback, validate `Origin`/`Host`, require a per-install or short-lived authenticated session, and explicitly define which RPC methods can write. These are proposed architecture requirements.
7. Decide the bridge deployment mode after testing browser local-network rules: a bridge-hosted local UI, or a hosted UI with a tested localhost connection/authentication flow. HTTPS, localhost security treatment, local-network permission, CORS, and WebSocket behavior must be validated together. Do not rely on current gaps in permission enforcement. [S8]
8. Keep audio playback/routing separate from device-control transport. The OS can own the earbud audio connection while the web/bridge owns a control channel, but their simultaneous availability is a hardware/platform unknown.

## Unknowns and next evidence needed

| Unknown | Why it matters | Next evidence |
| --- | --- | --- |
| Exact Chrome/macOS versions and hardware transport availability | User supplied OnePlus Buds 4, firmware 138.138.105, macOS and Chrome ([USER-001](evidence/user-environment.json)); features and transport behavior can still vary by installed versions. | Record browser/OS versions before later browser or hardware validation. Model identity is user supplied, not an independently inspected peripheral. |
| Actual HeyMelody communication transport | GATT, RFCOMM, or another native channel imply different feasibility. | Native transport classes/imports, connection call sites, service UUIDs, characteristic UUIDs, and stream APIs. |
| Whether the model advertises a usable GATT service | Native CoreBluetooth imports alone do not prove the control path is BLE or browser-accessible. | App call chain first; later a user-authorized read-only service inventory on the identified model. |
| Native encryption/authentication/session setup | Knowing opcodes alone may not create a functional client. | Handshake code, crypto dependencies, key derivation, replay/sequence rules, pairing requirements. |
| UUID blocklist/service-class eligibility | A working native endpoint can still be blocked in a browser. | Compare recovered exact UUIDs against [S4] and RFCOMM rules in [S3]. |
| Chunking and transfer throughput | Settings may work while firmware transfer fails. | Native framing/chunk constants, characteristic write mode, retries/windowing; later authorized measurements. |
| Advertisement/manufacturer-data dependence | Chooser filters may not reproduce native scanning/model identification. | Recovered advertising parsing and browser implementation support. |
| Device state while OS audio/native app are connected | Exclusive connections can break a control channel. | Native connection handling and later authorized coexistence tests. |
| Firmware provenance, signatures, transfer safety, and resumability | A complete firmware UI depends on more than uploading bytes. | Native updater call chain, metadata/download formats, authenticity checks, stage transitions. No update should be attempted during investigation. |
| Required background behavior | Native lifecycle behavior may be essential to parity. | App background modes and reconnect implementation; test target browser lifecycle later. |
| Any native-only hearing/calibration dependencies | Browser tones and device DSP programming may not preserve intended results. | DSP/test algorithms, audio APIs, calibration assumptions, and model-specific persistence commands. |

## Sources

All URLs were retrieved directly on 2026-10-12. These are specifications, browser vendor documentation/policy, and the compatibility dataset's own source repository. Vendor documentation establishes API intent, not a successful test with HeyMelody.

- **[S1] Chrome, “Communicating with Bluetooth devices over JavaScript.”** <https://developer.chrome.com/docs/capabilities/bluetooth>
- **[S2] WHATWG, Web Bluetooth specification.** <https://bluetooth.spec.whatwg.org/>. The former Community Group URL currently contains a redirect script to this location. Relevant sections: device selection/service authorization, GATT connection, characteristic writes, notification subscription, blocklist, `Navigator` integration, Permissions Policy.
- **[S3] Chrome, “Serial over Bluetooth on the web.”** <https://developer.chrome.com/blog/serial-over-bluetooth>. Relevant sections: Chrome 117 desktop support, nonstandard Service Class IDs, filters and restrictions.
- **[S4] Web Bluetooth registry, GATT blocklist**, file-changing commit `38ad58c9f5e5c8977a1349805ac12e73b5e7dd19` (2021-09-28): <https://github.com/WebBluetoothCG/registries/blob/38ad58c9f5e5c8977a1349805ac12e73b5e7dd19/gatt_blocklist.txt>. The published source list does not prove the exact installed browser uses that exact revision.
- **[S5] MDN Browser Compatibility Data, `api/Bluetooth.json`**, file-changing commit `94604b735d39cf71df87ad3f78682a2bb141d5a9` (2026-09-22): <https://github.com/mdn/browser-compat-data/blob/94604b735d39cf71df87ad3f78682a2bb141d5a9/api/Bluetooth.json>. Current characteristic API data was also inspected: <https://github.com/mdn/browser-compat-data/blob/main/api/BluetoothRemoteGATTCharacteristic.json>. Dataset entries are evidence of recorded compatibility, not device-specific tests.
- **[S6] WebKit, Tracking Prevention Policy**, fingerprinting section and list of declined APIs: <https://webkit.org/tracking-prevention/>
- **[S7] W3C, Audio Output Devices API.** <https://www.w3.org/TR/audio-output/>. Relevant sections: `HTMLMediaElement.setSinkId()`, `MediaDevices.selectAudioOutput()`, consent.
- **[S8] Chrome, “New permission prompt for Local Network Access.”** <https://developer.chrome.com/blog/local-network-access>. The retrieved document reports launch in Chrome 142 and describes then-current limitations; test actual target versions rather than treating those limitations as stable behavior.
- **[S9] Apple, “What's New in Core Bluetooth,” WWDC 2019 session 901**, transcript approximately 09:11–11:20: <https://developer.apple.com/videos/play/wwdc2019/901/>. Associated first-party sample: <https://developer.apple.com/documentation/corebluetooth/using-core-bluetooth-classic>.
- **[S10] Chromium source, `BluetoothLowEnergyAdapterApple`**, inspected current `main`, notably `RetrieveGattConnectedDevicesWithDiscoveryFilter`, `RetrieveGattConnectedDevicesWithService`, and `CreateGattConnection`: <https://github.com/chromium/chromium/blob/main/device/bluetooth/bluetooth_low_energy_adapter_apple.mm>. This is source evidence, not a test of the installed browser build.
- **[S11] Chromium source, `BluetoothDeviceChooserController`**, inspected current `main`, notably discovery-filter construction and `PopulateConnectedDevices`: <https://github.com/chromium/chromium/blob/main/content/browser/bluetooth/bluetooth_device_chooser_controller.cc>.
- **[S12] Apple, `CBConnectPeripheralOptionEnableTransportBridgingKey` documentation:** <https://developer.apple.com/documentation/corebluetooth/cbconnectperipheraloptionenabletransportbridgingkey>. Official documentation content was retrieved through its data endpoint: <https://developer.apple.com/tutorials/data/documentation/corebluetooth/cbconnectperipheraloptionenabletransportbridgingkey.json>.

## Subsequent hardware and build status

The statements above describe their original investigation phase. [Extended read-only validation](feature-validation.md) now directly confirms firmware 138.138.105, model 065414, inventory queries, live battery/wearing/noise events and one reconnect on macOS/Chrome. The first read-only dashboard is implemented and user-confirmed. Web Bluetooth GATT, setting changes and advanced-feature parity remain unvalidated.
