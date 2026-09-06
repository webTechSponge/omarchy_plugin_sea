# omarchy_plugin_sea

Read README.md and docs/architecture.md for product requirements; PROMPT.md, when present, is a local session brief. Use the Omarchy skill before user desktop integration. Never edit /usr/share/omarchy. Publish or push only when explicitly requested.

- Native Quickshell overlay, id `local.oma-plug-sea`, hosted by existing omarchy-shell.
- UI: PluginBrowser.qml, components/, js/. Helpers: bin/, lib/. Bash + curl/jq and a native Qt6 preview decoder; `qt6-imageformats` required. `bin/oma-plug-sea-build-preview` builds the bundled decoder into a private source/toolchain-keyed cache on first preview use for standard Git installs. `scripts/build-preview` prepares the development binary during mise setup/check; generated binaries stay untracked.
- Standard Git installation: install documented system dependencies, then `omarchy plugin add URL --enable`; open via shell summon IPC and remove with `omarchy plugin remove local.oma-plug-sea`. No mise or generated binary is needed in the checkout.
- `mise trust && mise run setup`; `mise run check`; `mise run install`; `mise run open`; `mise run smoke`.
- Development installation copies runtime files (manifest validator rejects symlinks). Re-run install after edits. Shipped runtime lives under runtime/<SHA256>/ with a stamped QML entrypoint; scripts/verify-runtime checks checkout, installed files and live build identity before desktop tests.
- User changes require timestamped backups, preserved JSONC menu entries, and supported plugin IPC/CLI.
- Catalog metadata is untrusted presentation data. Never execute upstream installCommand. Every mutation uses argument arrays, consent, locking, and checked local postconditions.
- See docs/platform-research.md and docs/architecture.md for verified interfaces and limitations.

Display name: **Omarchy Plugin Sea**. Repository directory: `omarchy_plugin_sea`. Keep existing CLI, manifest ID and storage identifiers stable unless a migration is requested.

Keep root `preview.png` synchronized with `docs/screenshots/browser-transparent-logo.png` when refreshing current listing screenshots.
