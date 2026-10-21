# macOS / Chrome transport validation

The user authorized transport validation after the static investigation. Scope: already paired Buds 4, host/browser checks, bounded connection observation and capability/identity/battery queries. Settings changes, pairing, locate sounds, hearing tests, resets and updates remain excluded. The diagnostic page is a research harness, not the requested web application.

## Host and browser evidence

[HOST-VALIDATION-001](evidence/host-validation.json):

- macOS **27.0.1**, build **26A434**.
- Installed Chrome initially **154.0.8037.93**. The user subsequently confirmed updating Chrome; current application metadata reports **155.0.8059.40**.
- The successful page reports reduced UA `Chrome/155.0.0.0`, consistent with the updated major version. The initial installation metadata is not the tested browser's exact version.
- macOS lists **OnePlus Buds 4** as connected, with `HFP AVRCP A2DP GATT ACL` labels. This alone does not establish RFCOMM.
- T3's Electron/Chromium 152 API availability is retained separately and is not counted as installed-Chrome validation.

## Proven connection result

User manually selected Buds 4 in Chrome's chooser. Session `a0286aac-4448-4e6d-bee6-7d32ad50333f` in [browser-transport-results.jsonl](evidence/browser-transport-results.jsonl) records:

| Event | UTC time / result |
|---|---|
| Service selected | 2026-10-12 14:20:36.931; `0000079A-D102-11E1-9B23-00025B00A5A5` |
| Port opened | 14:20:37.324; readable and writable streams present |
| Incoming data | 14:20:37.404; 68 bytes, contents not saved in this phase |
| Automatic close | 14:20:52.328; 15-second limit |
| Outbound application bytes | **0** |

The user confirmed selection/connection and supplied a matching screenshot, retained as [USER-002](evidence/user-transport-screen.json).

**Conclusion:** direct Chrome Web Serial custom-service RFCOMM access works at the connection level on this Mac with this selected device. A local bridge is not required merely to open this control transport. Complete command/reply compatibility, device identity and settings behavior require separate evidence.

The log may include subsequent sessions, embedded-browser rejection and chooser cancellations. These do not invalidate the successful identified session; assess each session's own browser and events.

## Automation limitation and manual path

Chrome browser-control selection returned unavailable, with no browser connections. Its native-messaging manifest was absent; a protected Chrome Local State diagnostic was inaccessible. No browser protection was bypassed or extension/native-host installation altered.

Browser-control automation was unavailable, so the chooser was confirmed in installed Chrome instead of a substitute browser.

## Diagnostic harness

The [page](evidence/transport-check.html) and [local server](evidence/serve_transport_check.py) bind to `127.0.0.1:8974`; result submissions require the exact local Origin/Host. Page serving and cross-origin rejection were verified. The first button opens the selected RFCOMM port without sending commands and closes after 15 seconds.

The separate **Read model and battery** button uses [state-check.js](evidence/state-check.js). It sends only:

| Query | Expected reply | Purpose |
|---|---|---|
| `0100`, sequence `31` | `8100`, matching sequence | Capability query; expect successful status |
| `0103`, sequence `32` | `8103`, matching sequence | Product identity; require model `065414` before continuing |
| `0106`, sequence `33` | `8106`, matching sequence | Battery; validate component/count/range structure |

No notification registration, time response, settings command, test or update is sent. The encoder rejects commands outside this allowlist. Replies are matched by command/sequence and checked against declared lengths; unrecognized responses are retained instead of guessed. Query-reply frame bytes are saved for evidence. Unsolicited frame contents are omitted.

Each query times out after four seconds; the session has a 25-second closure limit. `baudRate:9600` satisfies the Serial interface and is not a measured Bluetooth radio bitrate. Stream framing supports partial/combined reads and bounded one-to-three-byte LEB128 length fields; this intentionally covers the limited probe, not all packet variants.

Offline checks verified mutation-command rejection, fragmented identity-frame correlation, multi-byte length parsing and battery value bounds before exposing this button.

## Current status

**Connection and read-only state validation passed.** The user completed the check in session `aa713cde-3ade-4ca4-a42f-3189cc6f8d54`, then another successful session was recorded. [DEVICE-VALIDATION-001](evidence/device-validation.json) preserves the result and independent frame checks.

| Read result | Verified payload / interpretation |
|---|---|
| Capability reply `8100` | `00 FF 77 5A EA 67 0E 20 07`; matches QuickBuds' reported Buds 4 bitmap |
| Identity reply `8103` | `00 14 54 06`; LE model identifier `065414`, matching Buds 4 |
| Battery reply `8106` | `00 02 01 50 02 50`; left 80%, right 80%, neither charging; case omitted |

The documented session sent 27 application bytes across three query frames, **zero mutation commands**, then closed. Independent parsing of saved bytes verified command-bit response mapping, sequence echo, frame length and payload length. No firmware query was sent; firmware identity remains the prior user screenshot.

An unsolicited `0204` frame had sequence `10` (decimal 16), rather than `FF`. Its contents were not retained; do not assume all pushes have sequence `FF`. Record arrival order can differ from event timestamps because result submissions are asynchronous.

**Decision:** use Web Serial as the primary Chrome/macOS control transport. See [transport-decision.md](transport-decision.md). GATT remains an alternative; a bridge remains relevant for browser-unavailable/native OS functions. Settings writes, larger packets, reconnect/background operation, firmware, cloud and acoustic-equivalence questions remain unvalidated.

The diagnostic server was stopped after capture, and the probe sessions recorded closure. To rerun the saved check later, start `python3 docs/heymelody/evidence/serve_transport_check.py`; no server is left running by this validation.

## Subsequent hardware and build status

The statements above describe their original investigation phase. [Extended read-only validation](feature-validation.md) now directly confirms firmware 138.138.105, model 065414, inventory queries, live battery/wearing/noise events and one reconnect on macOS/Chrome. The first read-only dashboard is implemented and user-confirmed. Web Bluetooth GATT, setting changes and advanced-feature parity remain unvalidated.
