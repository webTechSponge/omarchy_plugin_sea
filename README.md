# Omarchy Plugin Sea

![Omarchy Plugin Sea wave-and-plug wordmark](assets/branding/wordmark-pluginsea-v4.png)

A native, theme-aware community plugin browser inside the existing Omarchy Quickshell desktop. Browse cards and previews, search names/authors/tags, filter by category or installation state, sort by name/stars/hearts/listing date, inspect provenance, and manage local plugins with explicit consent.

![Omarchy Plugin Sea with transparent branding, star counts and live catalog previews](preview.png)

## Install

Requires Omarchy with the Quickshell plugin CLI and a running shell. Standard Omarchy tools (Bash, curl, jq, Git, util-linux and coreutils) are used at runtime. Install the native preview dependencies if they are missing, then use Omarchy's standard installer:

```bash
omarchy pkg add qt6-imageformats gcc pkgconf qt6-base
omarchy plugin add https://github.com/webTechSponge/omarchy_plugin_sea --enable
```

On first preview use, the app automatically compiles its bundled Qt decoder into your private cache. It reuses that build and rebuilds when the decoder source or toolchain changes. There is no separate build/setup command, downloaded executable or administrative action inside the app. The first preview may take a few seconds; missing packages or build failures are explained on the detail page. Dependencies must already be installed: Omarchy does not install them from plugin manifests.

## Open

```bash
omarchy-shell shell summon webtechsponge.plugin-sea '{}'
```

For a standard Git installation, this is the opening command. Omarchy does not automatically create menu entries or launchers for overlays. The separate development-install workflow below adds `oma-plug-sea` and **Setup → Plugins → Browse**.

To update a standard installation, close the browser and run `omarchy plugin update webtechsponge.plugin-sea`. To remove it, run `omarchy plugin remove webtechsponge.plugin-sea`. The preview cache is retained and can be removed separately.

The repository directory is `omarchy_plugin_sea` and the visible application name is **Omarchy Plugin Sea**. The permanent manifest ID is `webtechsponge.plugin-sea`, authored by **webTechSponge** under the MIT license. The existing `oma-plug-sea` command and `oma_plug_sea` cache/state paths remain unchanged.

## Migration from the development ID

The permanent plugin ID is now `webtechsponge.plugin-sea`; earlier installations used `local.oma-plug-sea`. Remove the old installation before installing the new ID. An in-place Git update is not an ID migration.

For a **managed development installation**, run `mise run uninstall` from the **old checkout before updating its source**. Its old scripts remove the old ID, launcher and marked menu entry with recoverable backups. Then update the checkout and run `mise run install` to install the new ID. Do not run the new uninstall script to remove an old-ID installation.

For a **standard Git installation**, first back up any edits in `~/.config/omarchy/plugins/local.oma-plug-sea`; the removal command deletes that Git checkout. Then close and remove the old plugin and install the new one:

```bash
omarchy-shell shell hide local.oma-plug-sea
omarchy plugin remove local.oma-plug-sea
omarchy plugin add https://github.com/webTechSponge/omarchy_plugin_sea --enable
omarchy-shell shell summon webtechsponge.plugin-sea '{}'
```

Existing catalog, preview and decoder caches remain usable because their storage identifiers have not changed. If you have already updated the old checkout, recover its previous scripts before uninstalling, or review and remove the old integration separately; the new installer does not silently migrate user configuration.

## Development setup

The app uses a separate native Qt helper for preview decoding; no Python, Node, database, or web framework is required at runtime. In addition to the standard installation dependencies above, development integration needs Perl. Setup and checks require `qt6-declarative` (`qmllint` and the Qt6 QML runner), `libwebp` fixture APIs and `ripgrep`. The optional desktop keyboard smoke check requires `wtype`.

Install missing native dependencies from a terminal:

```bash
omarchy pkg add qt6-imageformats gcc pkgconf qt6-base qt6-declarative libwebp ripgrep
```

Use this workflow instead of the standard Git installation when developing the app. It creates a managed runtime copy and refuses to overwrite a standard Git installation. Use mise for the project environment and commands:

```bash
cd /path/to/omarchy_plugin_sea
mise trust
mise run setup
mise run check
mise run install
mise run open
```

`mise.toml` intentionally uses the system's matching Qt/Omarchy runtime instead of downloading a conflicting language stack. Setup builds the native preview helper and checks decoder support and native dependencies. The development installer copies the runtime files into `~/.config/omarchy/plugins/webtechsponge.plugin-sea`, creates `~/.local/bin/oma-plug-sea`, and adds one marked `setup.plugin.browse` property to the supported menu extension. It preserves other entries and comments, refuses unowned targets and symlinks, and backs up existing files under `${XDG_STATE_HOME:-~/.local/state}/oma_plug_sea/` before changes. No files under `/usr/share/omarchy` are edited.

Re-run `mise run install` after source changes. Omarchy validates against symlinks, so this uses a copy rather than a development symlink. If Quickshell retains a stale imported component after editing QML, run `omarchy restart shell` once and reopen. The installed host currently hardcodes `~/.config/omarchy`; cache and state storage honor XDG variables.

## Interaction

- Type to search; search is debounced and includes descriptions, IDs, tags and categories.
- Use category/state/sort selectors; refresh preserves search and filter context. While open, the browser checks the catalog source every five minutes and highlights **Refresh available** when it detects a change. Checks do not replace the catalog until you refresh.
- Cards show repository star counts; choose **Sort: name**, **Sort: stars**, **Sort: hearts** or **Sort: date**, then use the separate **↑ / ↓** button for ascending or descending order. For the most-starred repositories first, choose stars and **↓**. Direction stays unchanged when switching sort fields. Hover a count for its meaning, or the availability and catalog labels for plain-language explanations.
- Hearts are anonymous aggregate interactions reported by the omarchyplugins.com marketplace engagement API — not downloads, installs, unique people, or safety signals. "—" means the marketplace has no record for that plugin. Heart data refreshes alongside the catalog and is cached locally; if the engagement API is unreachable, the last saved counts stay visible and the catalog is unaffected. A **♥ Send a heart** button on catalog-listed details sends one anonymous heart after explicit consent (reported as an anonymous heart from the plugins.omarchy.org origin; rate-limited; one per plugin per computer); it never affects installs or verification.
- Down from search moves to cards; arrows navigate, Enter/Space open details. Click a card for the same view.
- Tab moves between controls. Ctrl+F returns to search; F5 refreshes. Escape cancels consent, returns from details, clears search, then closes.
- Details show source, preview or fallback, local version/state, upstream checks and exact review/observed commits when supplied.
- Click a detail preview (or focus it and press Enter/Space) to open the original-resolution viewer. Use Fit, 100%, zoom controls and scrolling/dragging to inspect it; Escape returns to the same detail page. Original images keep the existing download and decoder safety limits, with a separate cache from card previews.
- The Available filter shows only listings supported by the in-app installer; manual-only entries remain in All plugins.
- Catalog warnings such as quarantined or withdrawn remain visible even when a plugin is installed, including in action consent. Disable and remove remain available for recovery.
- Install defaults to disabled. Install & enable is a separate explicit choice. Enable, disable, update and removal appear according to local state.
- Operations show progress, capture stdout/stderr in Diagnostics, prevent conflicting actions, and confirm local state before reporting success.

## Catalog and trust

Verified on **2026-09-05**: `https://omarchyplugins.com/` redirects to `https://plugins.omarchy.org/`; the working deployed source is [`/catalog.json`](https://plugins.omarchy.org/catalog.json), containing 2,427 listings during verification. The marketplace's own source is [omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace). This is browse metadata, **not a signed installation registry**. See [platform research](docs/platform-research.md) for exact source contracts and official registry deployment probes.

Community plugins run **unsandboxed as your user**. Browsing and opening details never import their QML or execute their scripts. The browser never executes a catalog `installCommand`. It accepts canonical HTTPS GitHub repository sources for installation and delegates Git operations and manifest validation to `omarchy plugin add/enable/disable/update/remove`.

Consent snapshots the exact ID/source and clearly labels catalog verification and reviewed commits. For installed plugins, View installed source opens the installed origin; a separate Catalog source link identifies a differing listing repository. Missing or differing origins never inherit catalog verification. Even matching origins do not verify the installed revision. A listing marked “verified” describes the marketplace's snapshot checks, not a security audit. The installed Git CLI clones or updates **mutable HEAD**, which may differ from the listed reviewed commit. Updates of enabled code can execute it immediately; consent explicitly acknowledges skipping the CLI's interactive diff prompt.

Installation checks Git’s effective clone URL before calling Omarchy, so an existing Git URL rewrite cannot silently select another repository. After installation, the app checks the disabled checkout’s manifest and both its recorded and effective Git origins before reporting success or enabling it.

Updates carry the approved installed origin to the helper, which rejects changed, rewritten or ambiguous origins before invoking the CLI. Omarchy does not expose an atomic expected-origin update option: unrelated external Git configuration changes can still race the final check and fetch.

Install & enable first installs disabled, verifies the expected ID and then enables. A source changing its ID fails confirmation and can leave a disabled checkout to inspect. Installation is refused when undiscovered third-party IDs remain referenced in shell.json, since those dormant references could cause a supposedly disabled installation to load code. No configuration is silently removed to bypass that guard. Existing configuration is backed up before mutations. Bar widgets use their manifest's default placement through the supported enable command.

The official signed registry API/client was not deployed at verification time. When a real signed client ships, the catalog adapter can migrate independently, while all signature, checksum, freshness, compatibility, receipt and revocation enforcement must remain owned by that client. Current code does not fabricate those guarantees.

## Offline behavior

The last good normalized catalog lives at `${XDG_CACHE_HOME:-~/.cache}/oma_plug_sea/catalog.json`. Refresh uses 5-second connection and 25-second total timeouts and atomically replaces only a validated document. Malformed optional status values disable only the affected listing. Failed requests, malformed required entries and duplicate IDs preserve the good cache and return it with a visible stale indicator and refresh timestamp. Without any cache, the UI shows an honest empty/error state, retains local plugins, and offers Refresh. No fixture catalog is passed off as live data.

Previews are accepted only from the marketplace’s supported WebP asset URLs. Every accepted image goes through the restricted downloader and separate decoder; the desktop shell receives a cached PNG, never a remote image URL. Other formats, origins and failed previews display a fallback. Conversion is bounded and cached independently. Lifecycle commands have a 120-second timeout and a per-user action lock. A stopped shell, missing command, changed plugin state or unsuccessful postcondition produces a failure with diagnostics.

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
bash tests/standard-install.sh
bash tests/standard-cli-install.sh
scripts/test-integration
git diff --check
```

Desktop tests require the managed development installation; they are not intended to run against a standard Git installation. They first compare the checkout, installed files and a fingerprint reported by the running app. A mismatch fails the test and asks you to reinstall; a stale shell instance must be reopened or restarted. Each installed build uses its own runtime path so QML imports cannot be reused from another build.

The smoke test briefly creates an inert locally authored `local.oma-plug-sea-smoke` panel, enables, disables and removes it through the real helper/CLI, and verifies each postcondition. It never installs arbitrary third-party code. Development integration tests use isolated HOME and mocked CLI state. The standard-install regression uses the real Omarchy add/validate/catalog commands with a temporary local Git repository, while mocking shell IPC and the preview download. Another source-only test covers automatic compilation, concurrent cache reuse, source updates and failed-build recovery without mise. Backend tests exercise malformed/partial data, invalid URLs/IDs, stale cache, network and subprocess failures, concurrency, consent, source mismatches and false-success rejection. Model tests execute the actual JavaScript through Qt6.

[Architecture and helper schema](docs/architecture.md) · [Verification evidence](docs/verification.md) · [Contributor instructions](AGENTS.md)

## Troubleshooting

```bash
omarchy-shell shell ping
omarchy plugin list --json
omarchy-shell shell rescanPlugins
# Run this helper command from the project checkout:
bin/oma-plug-sea-catalog refresh | jq '{ok,stale,error,count:(.plugins|length)}'
omarchy-shell shell call webtechsponge.plugin-sea status '{}'
quickshell log -p "$OMARCHY_PATH/shell" -t 100 --no-color
```

If the shell is stopped, use `omarchy restart shell`. A standard Git installation does not add `oma-plug-sea` to PATH; use the [Open](#open) IPC command. The `~/.local/bin/oma-plug-sea` launcher exists only after development integration. If summon reports that the plugin is disabled, run `omarchy plugin enable webtechsponge.plugin-sea` and try again. A source/ID mismatch requires inspecting local plugin directories before retrying. A dormant-reference error requires reviewing stale shell.json references; restore from a backup if needed. An action lock error means another browser operation is running. Terminal-driven operations do not share this lock, so concurrent external changes can fail a postcondition and require refresh.

### Preview setup problems

The first uncached preview may show **Preparing preview…** while the bundled decoder builds. If dependencies are missing, install the packages shown in the detail-page error, then reopen the detail page to retry. Compilation is limited to 60 seconds; a failed build is not published and the next request can try again.

For a standard Git installation, this optional diagnostic command prepares the decoder and prints its cached executable path:

```bash
~/.config/omarchy/plugins/webtechsponge.plugin-sea/bin/oma-plug-sea-build-preview
```

The decoder cache is `${XDG_CACHE_HOME:-~/.cache}/oma_plug_sea/decoder-builds/`; downloaded/converted images are in the sibling `previews/` directory. Builds are keyed by source and toolchain, so updates rebuild automatically when needed. Removing these caches is optional; subsequent previews recreate them. Already cached PNGs can be displayed without a compiler or a new download.

## Removal and recovery

For a **standard Git installation**, close the browser and use Omarchy's normal removal command:

```bash
omarchy plugin remove webtechsponge.plugin-sea
```

This removes the installed Git checkout through Omarchy. Reinstall with the [standard install commands](#install).

For a **managed development installation**, run this from the project checkout while the shell is running:

```bash
mise run uninstall
```

This hides/disables the browser, moves its managed copy into the recoverable state directory, removes only its marked menu block and launcher, rescans, and verifies it is undiscovered. Other extensions/configuration remain. The source checkout is independent. Reinstall this development integration with `mise run install`.

Both workflows retain app caches and existing recovery data. You can manually delete `${XDG_CACHE_HOME:-~/.cache}/oma_plug_sea` and `${XDG_STATE_HOME:-~/.local/state}/oma_plug_sea` once you no longer need cached browsing or backups. Development uninstall deliberately refuses to remove an ordinary Git installation; choose the command matching how you installed the app.

## Known limits

These limits mostly concern installing and updating plugins. You can still browse the catalog, inspect details and previews, and search cached listings offline.

### Some plugins need manual installation

The app can install plugins whose GitHub repositories follow the structure supported by Omarchy's installer. Some listings contain several plugins in one repository, need custom setup, or replace a larger part of the desktop. You can browse those listings and open their source, but you must follow the author's installation instructions yourself. The **Available** filter shows only listings supported by the in-app installer.

### Catalog checks do not guarantee the code you install

When you install or update a plugin, Omarchy fetches the repository's current code. Its author may have changed that code since the catalog checked it. A **verified** catalog label therefore does not mean the plugin is safe, or that your installed version was checked.

The current installer does not use signed releases that would let it authenticate the exact version described by the catalog. Community plugins run with your user account's permissions when enabled, so only enable code you trust. **Install disabled** lets you inspect the downloaded code before enabling it; it does not make that code safe automatically.

### A catalog refresh is different from a plugin update

**Refresh available** means the catalog has changed—for example, a new plugin was listed or a description was updated. It does not necessarily mean any of your installed plugins have updates.

The app cannot reliably show an update-available badge for each installed plugin in advance. **Check & update** checks the installed plugin's repository and applies an update if one is available; it is not a check-only action. Updating an enabled plugin may run its new code immediately, so the app asks for consent first.

### Remove Plugin Sea from the terminal

Plugin Sea cannot disable or uninstall itself through its own interface. Doing so could interrupt an operation before it finishes or reports its result.

For a standard Git installation, run `omarchy plugin remove webtechsponge.plugin-sea`. For the managed development installation, run `mise run uninstall` from this project's directory while the Omarchy shell is running. The development command also removes its launcher and menu entry while retaining recovery backups. See [Removal and recovery](#removal-and-recovery) for details.

### Missing information does not mean missing permissions

Some catalog entries omit compatibility results, capabilities or other details. The app reports those fields as unknown. For example, missing information about file access does **not** mean a plugin cannot read your files: enabled community plugins run with your account's permissions.

### Avoid changing the same plugin in two places at once

The app prevents its own management operations from overlapping, but it cannot stop a terminal command or another program from changing the same plugin.

For example, a plugin's Git origin could change while its update consent dialog is open. The app checks the origin again and refuses the update if it detects a change. However, Omarchy's update command cannot make that check and the subsequent fetch one indivisible operation, so an external change in between can still slip through. Installation has similar source checks before cloning and before enabling, with the same limitation around simultaneous external changes. Avoid managing the same plugin simultaneously through the app and a terminal.

Setting up Plugin Sea does not publish your project, push code to GitHub, submit a marketplace listing, or install community plugins. Those are separate actions you choose.

MIT licensed.
