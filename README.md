# Omarchy Plugin Sea

A native, theme-aware community plugin browser inside the existing Omarchy Quickshell desktop. Browse cards and previews, search names/authors/tags, filter by category or installation state, sort by name/stars/listing date, inspect provenance, and manage local plugins with explicit consent.

![Omarchy Plugin Sea with live catalog previews](docs/screenshots/browser.png)

## Open

```bash
oma-plug-sea
# Or: Setup → Plugins → Browse
# Stable IPC route:
omarchy-shell shell summon local.oma-plug-sea '{}'
```

The repository directory is `omarchy_plugin_sea` and the visible application name is **Omarchy Plugin Sea**. The existing `oma-plug-sea` command, `local.oma-plug-sea` manifest ID, and cache/state paths are retained for compatibility.

## Requirements and setup

Omarchy with the current plugin CLI, a running Quickshell shell, Bash, curl, jq, Git, util-linux (`flock`, `prlimit`), coreutils (`timeout`), Perl, and Qt6 with `qt6-imageformats` for WebP previews. A small native Qt helper decodes previews in a separate process and caches PNGs. ImageMagick is not required. No Python, Node, database, or web framework is required. Building from source needs `g++`, `pkg-config` and Qt6 development files (`gcc`, `pkgconf`, `qt6-base` on Arch). Developer checks also use `qmllint`, the Qt6 QML runner and `libwebp` fixture APIs.

Install missing native dependencies from a terminal:

```bash
omarchy pkg add qt6-imageformats gcc pkgconf qt6-base
```

Use mise for the project environment and commands:

```bash
cd /path/to/omarchy_plugin_sea
mise trust
mise run setup
mise run check
mise run install
mise run open
```

`mise.toml` intentionally uses the system's matching Qt/Omarchy runtime instead of downloading a conflicting language stack. Setup builds the native preview helper and checks decoder support and native dependencies. The development installer copies the runtime files into `~/.config/omarchy/plugins/local.oma-plug-sea`, creates `~/.local/bin/oma-plug-sea`, and adds one marked `setup.plugin.browse` property to the supported menu extension. It preserves other entries and comments, refuses unowned targets and symlinks, and backs up existing files under `${XDG_STATE_HOME:-~/.local/state}/oma_plug_sea/` before changes. No files under `/usr/share/omarchy` are edited.

Re-run `mise run install` after source changes. Omarchy validates against symlinks, so this uses a copy rather than a development symlink. If Quickshell retains a stale imported component after editing QML, run `omarchy restart shell` once and reopen. The installed host currently hardcodes `~/.config/omarchy`; cache and state storage honor XDG variables.

## Interaction

- Type to search; search is debounced and includes descriptions, IDs, tags and categories.
- Use category/state/sort selectors; refresh preserves search and filter context. While open, the browser checks the catalog source every five minutes and highlights **Refresh available** when it detects a change. Checks do not replace the catalog until you refresh.
- Down from search moves to cards; arrows navigate, Enter/Space open details. Click a card for the same view.
- Tab moves between controls. Ctrl+F returns to search; F5 refreshes. Escape cancels consent, returns from details, clears search, then closes.
- Details show source, preview or fallback, local version/state, upstream checks and exact review/observed commits when supplied.
- Click a detail preview (or focus it and press Enter/Space) to open the original-resolution viewer. Use Fit, 100%, zoom controls and scrolling/dragging to inspect it; Escape returns to the same detail page. Original images keep the existing download and decoder safety limits, with a separate cache from card previews.
- Install defaults to disabled. Install & enable is a separate explicit choice. Enable, disable, update and removal appear according to local state.
- Operations show progress, capture stdout/stderr in Diagnostics, prevent conflicting actions, and confirm local state before reporting success.

## Catalog and trust

Verified on **2026-09-05**: `https://omarchyplugins.com/` redirects to `https://plugins.omarchy.org/`; the working deployed source is [`/catalog.json`](https://plugins.omarchy.org/catalog.json), containing 2,427 listings during verification. The marketplace's own source is [omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace). This is browse metadata, **not a signed installation registry**. See [platform research](docs/platform-research.md) for exact source contracts and official registry deployment probes.

Community plugins run **unsandboxed as your user**. Browsing and opening details never import their QML or execute their scripts. The browser never executes a catalog `installCommand`. It accepts canonical HTTPS GitHub repository sources for installation and delegates Git operations and manifest validation to `omarchy plugin add/enable/disable/update/remove`.

Consent shows the exact ID/source, catalog verification status, reviewed commit and warning. A listing marked “verified” describes the marketplace's snapshot checks, not a security audit. The installed Git CLI clones or updates **mutable HEAD**, which may differ from the listed reviewed commit. Updates of enabled code can execute it immediately; consent explicitly acknowledges skipping the CLI's interactive diff prompt.

Install & enable first installs disabled, verifies the expected ID and then enables. A source changing its ID fails confirmation and can leave a disabled checkout to inspect. Installation is refused when undiscovered third-party IDs remain referenced in shell.json, since those dormant references could cause a supposedly disabled installation to load code. No configuration is silently removed to bypass that guard. Existing configuration is backed up before mutations. Bar widgets use their manifest's default placement through the supported enable command.

The official signed registry API/client was not deployed at verification time. When a real signed client ships, the catalog adapter can migrate independently, while all signature, checksum, freshness, compatibility, receipt and revocation enforcement must remain owned by that client. Current code does not fabricate those guarantees.

## Offline behavior

The last good normalized catalog lives at `${XDG_CACHE_HOME:-~/.cache}/oma_plug_sea/catalog.json`. Refresh uses 5-second connection and 25-second total timeouts and atomically replaces only a validated document. Failed requests, malformed entries and duplicate IDs preserve the good cache and return it with a visible stale indicator and refresh timestamp. Without any cache, the UI shows an honest empty/error state, retains local plugins, and offers Refresh. No fixture catalog is passed off as live data.

Preview failures display a fallback. Preview conversion is bounded and cached independently. Lifecycle commands have a 120-second timeout and a per-user action lock. A stopped shell, missing command, changed plugin state or unsuccessful postcondition produces a failure with diagnostics.

## Development and verification

```bash
mise run check
# Actual desktop smoke: summon/hide and controlled inert local panel lifecycle
mise run smoke
scripts/keyboard-smoke
# Explicit individual checks
omarchy plugin validate .
for f in bin/* scripts/*; do bash -n "$f"; done
bash tests/backend.sh
bash tests/model.sh
scripts/test-integration
git diff --check
```

The smoke test briefly creates an inert locally authored `local.oma-plug-sea-smoke` panel, enables, disables and removes it through the real helper/CLI, and verifies each postcondition. It never installs arbitrary third-party code. Integration tests use isolated HOME and mocked CLI state; backend tests exercise malformed/partial data, invalid URLs/IDs, stale cache, network and subprocess failures, concurrency, consent, source mismatches and false-success rejection. Model tests execute the actual JavaScript through Qt6.

[Architecture and helper schema](docs/architecture.md) · [Verification evidence](docs/verification.md) · [Contributor instructions](AGENTS.md)

## Troubleshooting

```bash
omarchy-shell shell ping
omarchy plugin list --json
omarchy-shell shell rescanPlugins
bin/oma-plug-sea-catalog refresh | jq '{ok,stale,error,count:(.plugins|length)}'
omarchy-shell shell call local.oma-plug-sea status '{}'
quickshell log -p "$OMARCHY_PATH/shell" -t 100 --no-color
```

If the shell is stopped, use `omarchy restart shell`. If `oma-plug-sea` is not on your PATH, use `~/.local/bin/oma-plug-sea` or the IPC route. A source/ID mismatch requires inspecting local plugin directories before retrying. A dormant-reference error requires reviewing stale shell.json references; restore from a backup if needed. An action lock error means another browser operation is running. Terminal-driven operations do not share this lock, so concurrent external changes can fail a postcondition and require refresh.

## Removal and recovery

```bash
mise run uninstall
```

With the shell running, this hides/disables the browser, moves its managed copy into the recoverable state directory, removes only its marked menu block and launcher, rescans, and verifies it is undiscovered. Other extensions/configuration remain. Backups and caches are intentionally retained; delete `${XDG_CACHE_HOME:-~/.cache}/oma_plug_sea` and `${XDG_STATE_HOME:-~/.local/state}/oma_plug_sea` manually once you no longer need recovery. The source checkout is independent and can be removed separately. Reinstall with `mise run install`.

## Known limits

- Current installation uses mutable HTTPS GitHub repositories; manual suites/subdirectory listings remain browse-only.
- No signed registry or reliable pre-update availability badge exists on this platform.
- The browser protects itself from in-app disable/remove; use its development uninstall command.
- Catalog-provided capability/check metadata is incomplete. Missing fields are reported as unknown rather than inferred guarantees.
- CLI mutation locks cover this application's operations only. External terminal actions can race and will be caught where possible by postcondition checks.

MIT licensed. No publication, remote push, marketplace submission, or third-party installation is performed by development setup.
