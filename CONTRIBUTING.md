# Contributing to OpenBuds

Thanks for helping. A few things keep the project easy to review.

## Branches

- `dev` is where all work lands. Open your pull request against `dev`.
- `main` is the release branch. A release is a pull request from `dev` into `main`.
- Both branches are protected: every pull request needs one approving review.

Merging into `main` builds `OpenBuds.dmg`, publishes a GitHub Release, and redeploys [openbuds.yashasewi.me](https://openbuds.yashasewi.me). Pushes to `dev` do neither.

## Before you open a pull request

- Mac app: `cd native && ./scripts/build-app.sh` builds and launches it. Try the change against real earbuds if it touches the protocol.
- Web app: `cd app && pnpm install && pnpm build` must succeed. `pnpm dev` serves it at `http://localhost:5173/`.
- Keep the two clients in step. A protocol change usually belongs in both `native/Sources/BudsKit` and `app/src/lib`.
- Describe what you tested in the pull request. Say which earbuds and firmware you used.

## Protocol changes

Every command both apps send is listed in an allow-list (`allowed` in `native/Sources/BudsKit/Protocol.swift` and its twin in `app/src/lib/protocol.ts`). Add a new command there with a payload check. Don't add firmware updates, factory reset, or anything that can't be undone from the app.

The frame format is in [docs/protocol.md](docs/protocol.md).

## Icons and images

`app/public/icon.svg` is the source of the app icon, the favicon, and the link preview. After changing it, run `swift scripts/make-icon.swift` inside `native/`. That rewrites `native/Support/AppIcon.icns` and the PNGs in `app/public`.

## Website hosting

Cloudflare Pages builds the site from this repository:

- Production branch: `main`. Preview deployments are off.
- Root directory: `app`
- Build command: `pnpm install && pnpm exec vp build`
- Output directory: `dist`
- `NODE_VERSION` = `22`

Start a commit message with `[CF-Pages-Skip]` to skip a site build.

## License

By contributing, you agree that your work is released under [GPL-3.0-or-later](LICENSE).
