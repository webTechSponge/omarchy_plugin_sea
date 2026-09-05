# omarchy_plugin_sea

Read README.md and docs/architecture.md for product requirements; PROMPT.md, when present, is a local session brief. Use the Omarchy skill before user desktop integration. Never edit /usr/share/omarchy. Publish or push only when explicitly requested.

- Native Quickshell overlay, id `local.oma-plug-sea`, hosted by existing omarchy-shell.
- UI: PluginBrowser.qml, components/, js/. Helpers: bin/, lib/. Bash + curl/jq, no additional runtime.
- `mise trust && mise run setup`; `mise run check`; `mise run install`; `mise run open`; `mise run smoke`.
- Development installation copies runtime files (manifest validator rejects symlinks). Re-run install after edits.
- User changes require timestamped backups, preserved JSONC menu entries, and supported plugin IPC/CLI.
- Catalog metadata is untrusted presentation data. Never execute upstream installCommand. Every mutation uses argument arrays, consent, locking, and checked local postconditions.
- See docs/platform-research.md and docs/architecture.md for verified interfaces and limitations.

Display name: **Omarchy Plugin Sea**. Repository directory: `omarchy_plugin_sea`. Keep existing CLI, manifest ID and storage identifiers stable unless a migration is requested.
