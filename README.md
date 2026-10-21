# OpenBuds

Local controllers for **OnePlus Buds 4**. A macOS menu-bar app and a Chrome page talk to the earbuds from this computer. There is no account and no cloud service inside the earbuds' link.

![OpenBuds menu bar panel](docs/panel.png)

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black)](https://github.com/Yashasewi/oneplus-buds-control/releases/latest)
[![GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)
[![Download](https://img.shields.io/badge/download-OpenBuds.dmg-brightgreen)](https://github.com/Yashasewi/oneplus-buds-control/releases/latest/download/OpenBuds.dmg)

## Install the Mac app

1. Download [OpenBuds.dmg](https://github.com/Yashasewi/oneplus-buds-control/releases/latest/download/OpenBuds.dmg) (Apple silicon, macOS 26 or later).
2. Open the disk image and drag **OpenBuds** to **Applications**.
3. Open OpenBuds. macOS says it could not verify the app. The build is ad-hoc signed so the file is intact, and it is not notarized with an Apple Developer ID. Click **Done**, then open **System Settings → Privacy & Security** and click **Open Anyway**. macOS remembers that choice. Right-click **Open** does not skip this warning on macOS 15 or later. A double-click with no warning would need the paid Apple Developer Program, which this project does not use.
4. Allow Bluetooth when macOS asks.
5. Connect the earbuds in Bluetooth settings if they are not already connected. OpenBuds connects by itself.

Quit HeyMelody, or any Chrome tab that is already connected. Only one app can hold the earbuds' control link.

If the earbuds icon never appears in the menu bar, open **System Settings → Menu Bar** and turn **OpenBuds** on.

To start it with your Mac, open the panel, go to **Features**, and turn on **Open at login**.

### Build it yourself

Building on your own Mac signs the app for that machine, so the Open Anyway step above does not apply.

You need macOS 26 or later and Xcode from the App Store. The script uses `/Applications/Xcode.app` when `DEVELOPER_DIR` is unset.

```sh
git clone https://github.com/Yashasewi/oneplus-buds-control.git
cd oneplus-buds-control/native
./scripts/build-app.sh --install
```

That builds a release, ad-hoc signs it, copies it to `/Applications/OpenBuds.app`, and opens it. `./scripts/build-app.sh` without `--install` launches the copy in `native/.build/` instead. The app must run as a bundle: macOS does not open Bluetooth RFCOMM channels for a bare command-line binary.

`native/scripts/make-icon.swift` draws `native/Support/AppIcon.icns`. Run `swift scripts/make-icon.swift` inside `native/` to regenerate it. The build copies the existing icon and does not redraw it.

## Web app

The page is also on the web, and that page has a **Download for Mac** button. Chrome's Web Serial API needs `https://` or `localhost`, so the hosted page works in desktop Chrome. The first **Connect** on that address is a new permission, separate from `localhost`.

To run it yourself you need Node.js 22.18 or newer and pnpm:

```sh
cd app
pnpm install
pnpm dev
```

Open [http://localhost:5173/](http://localhost:5173/) in desktop Chrome, not `127.0.0.1`. Chrome remembers the earbuds per address. `pnpm build` writes `app/dist`.

### Cloudflare Pages

Connect this GitHub repo in the Cloudflare dashboard (**Workers & Pages → Create → Pages → Connect to Git**). Install the Cloudflare GitHub app on this repository only.

- Production branch: `main`. Pushes to `dev` do not update the live site.
- Root directory: `app`
- Build command: `pnpm install && pnpm exec vp build`
- Build output directory: `dist`
- Environment variable: `NODE_VERSION` = `22`

A merge to `main` publishes the site. Prefix a commit message with `[CF-Pages-Skip]` to skip a site build when a release only changes the Mac app. A Git-connected Pages project cannot be switched to Direct Upload later.

## Features

Both apps can read battery, wearing, firmware, noise mode, the equalizer, gestures, feature switches, connected devices, the audio codec, BassWave, and prompt volume. Both can change noise control and ANC strength, the touch-and-hold cycle, equalizer presets, gestures and call controls, and the feature switches. Tools are find my earbuds, the fit test, and the Golden Sound hearing test.

The Mac app also sets the Mac's output volume, shows a card when the earbuds connect, notifies you at 20% and 10% battery, and can open at login.

Every change waits for the earbuds to accept it, then reads the setting back.

## Requirements

- Mac app: macOS 26 or later, Apple silicon for the downloaded disk image. Xcode to build from source.
- Web app: desktop Google Chrome, Node.js 22.18 or newer, pnpm.

## Limits

- OnePlus Buds 4 only, exercised on firmware 138.138.105.
- Hi-Res audio needs the LHDC codec. macOS connects with AAC, and the earbuds refuse Hi-Res on that link.
- Firmware updates, resets, pairing, ear scans, and cloud features are not implemented.
- Only one program can hold the control link at a time.

## Development

Day-to-day work happens on `dev`. A release is a pull request from `dev` into `main`. Merging that pull request builds `OpenBuds.dmg` and attaches it to a GitHub Release. The wire format is described in [docs/protocol.md](docs/protocol.md).

## Credits

- [QuickBuds](https://github.com/spizganed/QuickBuds) by spizganed, GPL-3.0-or-later. The command bitmap in both apps is from `desktop/src/protocol.rs`.
- [OppoPodsManager](https://github.com/Zhaoyi-ya/OppoPodsManager), GPL-3.0-or-later. An earlier protocol write-up that the notes cite.
- [Pods-Protocol](https://github.com/Star-ZER0/Pods-Protocol-Reverse-Engineering), CC-BY-SA-4.0. A format reference.
- [Geologica](https://fonts.google.com/specimen/Geologica), shipped through `@fontsource-variable/geologica`.

HeyMelody is the behavior reference for these earbuds. OpenBuds does not include HeyMelody's code.

## License

[GPL-3.0-or-later](LICENSE).
