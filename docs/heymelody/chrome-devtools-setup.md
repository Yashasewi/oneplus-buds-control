# Project Chrome DevTools MCP setup

Installed 2026-10-12 at the user's request. Project configuration: [.codex/config.toml](/Users/yash/Desktop/Personal/REA/.codex/config.toml).

Codex launches `npx -y chrome-devtools-mcp@latest`. The verified package version is **1.10.1**, on Node **24.13.0**, Codex CLI **0.159.2** and Chrome **155.0.8059.40**.

## Configuration

- Server name: `chrome-devtools`.
- Project scope: `/Users/yash/Desktop/Personal/REA/.codex/config.toml`.
- `--isolated`: launch Chrome with a temporary separate profile.
- `--no-usage-statistics` and `--no-performance-crux`: disable the server's usage telemetry and CrUX integration.
- Startup timeout: 60 seconds; tool timeout: 120 seconds.

Codex initially ignored the project configuration. Registering this exact folder as trusted in `~/.codex/config.toml` made it load. Only that project-trust entry was added to user configuration; the MCP server definition remains project-local.

## Verification

[Codex registration](evidence/chrome-devtools-codex-registration.json) confirms the server is enabled and resolves its project command/arguments.

[MCP smoke result](evidence/chrome-devtools-smoke.json) confirms:

1. MCP initialization succeeds and reports server version 1.10.1.
2. The server advertises **30 tools**.
3. `list_pages` starts Chrome and finds an `about:blank` page.
4. `evaluate_script` successfully reads that page's URL/title/user agent, reporting Chrome major 155.

The smoke test performed no Bluetooth operations or device queries. Its stdio client was closed after verification.

## Using it in Codex

Reload/restart the Codex session for its tool inventory to load the new server. The current running agent's advertised tool set is separate from the saved configuration; a successful CLI registration does not retroactively add a tool namespace to an existing session.

This setup starts a dedicated Chrome instance when a browser tool is first used. A new profile may require selecting the Buds 4 again in the Web Serial chooser. No Chrome extension is required for this launch mode.

The user previously authorized remaining read-only feature/event/reconnection validation and the first web version; this installation supplies the browser tools for that work. Device-setting mutations are still outside that scope. No new device validation was performed during installation.

## Primary setup references

- Official Codex MCP documentation: `https://developers.openai.com/codex/mcp/`
- Official project configuration documentation: `https://developers.openai.com/codex/config-basic/`
- Requested repository: `https://github.com/ChromeDevTools/chrome-devtools-mcp`
- Repository docs reviewed at commit `69524f0948d0ef93a93d17a6ca55f44d5e8d5916`: `docs/client-configurations.md`, `docs/configuration.md`, `docs/advanced-usage.md`.
