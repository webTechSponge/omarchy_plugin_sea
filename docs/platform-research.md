# Verified platform and catalog contracts

Verified **2026-09-05**, on installed Omarchy `dev (f632d26b)`. This is evidence for the implementation, not a promise about future upstream behavior. No packaged Omarchy source or user configuration was modified during research. The active shell uses `$OMARCHY_PATH` (a user-owned checkout on this machine), not necessarily `/usr/share/omarchy`. All researched READMEs, PluginRegistry, lifecycle CLI commands, and representative QML files were compared byte-for-byte with the active checkout and are identical. Inspect active runtime logs with `quickshell log -p "$OMARCHY_PATH/shell"`.

## Installed host

Read `/usr/share/omarchy/shell/README.md`, `shell/plugins/README.md`, `shell/services/PluginRegistry.qml`, the installed `omarchy-plugin-{add,enable,disable,update,remove,list,catalog,validate}` commands, and the Omarchy skill and its `plugins.md` guide. `omarchy plugin --help`, `omarchy plugin list --json`, and `omarchy-shell --help` succeed. The shell is running and discovers an existing user-owned plugin clone.

- Entry point is an `Item`, exposing `open(payloadJson)` and `close()`, with injected `shell`, `manifest`, `pluginRegistry`, and optionally `omarchyPath`. Use schema version 1, nonreserved ID `webtechsponge.plugin-sea`, `kinds: ["overlay"]`, `entryPoints.overlay: "PluginBrowser.qml"`. `keepLoaded` keeps state and subprocess ownership stable between summons.
- `omarchy-shell shell summon webtechsponge.plugin-sea '{}'`, `hide`, `ping`, and `rescanPlugins` are supported. The wrapper does **not** start a stopped shell. Do not use `-q` for postcondition verification: it intentionally reports success when IPC fails.
- `PluginRegistry.installedPlugins` contains full manifests with `__sourceDir` and `__isFirstParty`. `isEnabled(id)` consults effective config. `pluginsChanged` and `scanFinished` signal refreshes. Canonical identity is manifest ID.
- `omarchy plugin list --json` returns an array with `id`, `name`, `kinds`, `enabled`, `active`, `canDisable`, `firstParty`, `clonedFrom`; it does **not** expose version or source path. Hidden `omarchy plugin catalog` emits **local** manifests with computed source paths, not a community catalog. It also omits version.
- User plugins are discovered at `~/.config/omarchy/plugins/<id>/manifest.json`; discovery can follow symlinks, but installation validation rejects them; the development workflow installs copies, while the standard installer keeps a Git checkout. Hidden dot directories are ignored. Enabled state is persisted by the shell in `shell.json`; the config is authoritative, not deep-merged defaults.
- Native style references: `shell/plugins/emojis/Emojis.qml` supplies searchable grid, `GridView.Contain`, focus and Escape behavior, `Color.menu.*`, `Style`, `BorderSurface`, full-screen `PanelWindow`, overlay layer and exclusive keyboard focus. `shell/plugins/image-picker/ImagePicker.qml` supplies scalable image selection and request serials. `shell/plugins/panels/speedtest/Panel.qml` demonstrates command arrays, concurrent-process guards, timeout handling and stderr collectors. Collector completion and process exit can arrive in either order.
- User menu file `~/.config/omarchy/extensions/omarchy-menu.jsonc` merges dotted object keys. Correct entry is `setup.plugin.browse` (singular **plugin**); parent `setup.plugin` already displays **Plugins** under Setup. Static action can invoke the project launcher. Preserve existing JSONC and create a backup before minimal insertion; the file hot-reloads.

## Actual catalog available today

`https://omarchyplugins.com/` redirects to `https://plugins.omarchy.org/`. The latter currently serves the community marketplace, whose primary source repository is [omacom/omarchy-plugin-marketplace](https://github.com/omacom/omarchy-plugin-marketplace). Live endpoint:

```sh
curl --fail --location --connect-timeout 8 --max-time 30 https://plugins.omarchy.org/catalog.json
```

Observed HTTP 200 JSON, `mode: production`, `stateSchemaVersion: 2`, `generatedAt: 2026-09-05T19:01:13.199Z`, **2,427 entries**. Top-level keys: `generatedAt`, `mode`, `plugins`, `stateSchemaVersion`, `warnings`. Treat count/time as observation, not assertions in tests.

Entry fields observed: `id`, `name`, `description`, `author`, `version`, `category`, `tags`, `repo`, `sourceType` (`community` or `builtin`), display `kind`, `repositoryLayout` (`root-plugin`, `monorepo`, `suite`), `manifestPath`, `installAvailable`, `installNote`, `license`, `stars`, `repositoryUpdatedAt`, `previewImage`, `previewThumbnail`, `status`. Preview URLs may be relative `assets/img/plugins/...`; resolve against the catalog origin. Availability false includes shell suites requiring their own manual installation. **Never execute `installCommand`**; it is presentation metadata and frequently requests immediate enable.

Trust-related fields: `verificationStatus`, `verificationSnapshotStatus`, `verificationCoverage`, `verificationCommit`, `verificationCheckedAt`, `listingValidatedCommit`, `upstreamObservedCommit`, `upstreamCheckStatus`, `upstreamValidatedCommit`, and corresponding timestamps. Unknown fields should be ignored; missing optional values displayed honestly. Invalid required identity/source entries should not become installable. Reject malformed whole responses before replacing a good cache.

[Marketplace verification policy](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md) ties limited automated checks and some maintainer review to exact commits. `snapshot-verified` differs from `update-unverified`. Verification is not a security audit, endorsement, or safety guarantee. Even a matching observed SHA cannot guarantee the next clone: the installer follows mutable upstream HEAD.

## Lifecycle and safety implications

- `omarchy plugin add <git-url> --yes` clones, validates, and lands **disabled**. `--enable` exists, but there is no exact-SHA/ref input. The CLI does not run installation hooks. Never derive an executable shell command from catalog strings.
- For install-and-enable, safer composition is add disabled, verify the requested canonical ID exists and expected source was installed, then enable that ID. Passing `--enable` directly could execute a changed manifest ID that was not named in consent.
- `enable <id>` uses `barWidget.defaultSection`, falling back to center; optional `--section left|center|right` is supported. A full bar replaces the active bar. Respect the list's `canDisable` field.
- `update <id> --yes` fetches `origin HEAD`, fast-forwards, validates, and hard-rolls back invalid updates. `--yes` suppresses both diff and prompt. Native consent must cover replacing code from mutable upstream; update availability cannot be inferred safely just from a browse version string. It can trigger live code reload for enabled plugins.
- `remove <id> --yes` unlinks development symlinks, deletes Git checkouts, or backs up non-Git directories under a hidden timestamped sibling. It disables and rescans. Native confirmation should identify the plugin and removal semantics.
- Add/update/remove require `--yes` in a noninteractive GUI only after equivalent explicit native consent. All actions need bounded process lifetime, captured errors, serialized mutations, rescan and state verification; a zero exit status alone is insufficient.
- Browse/detail operations must never fetch executable plugin code or run plugin code. Preview images are fetched only from the fixed marketplace asset origin and decoded in a separate restricted process; user source links should be HTTPS and opened via argument arrays.

## Official signed registry migration

The official repository [omacom/omarchy-plugin-registry](https://github.com/omacom/omarchy-plugin-registry) contains current [browse API](https://github.com/omacom/omarchy-plugin-registry/blob/main/docs/browse-api.md) and [client specification](https://github.com/omacom/omarchy-plugin-registry/blob/main/docs/client-spec.md). It describes unsigned `/plugins.json` (snake_case schema_version 1, paged metadata and notices) and a signed static install plane (`config.json`, `all.json`, per-plugin index, revocations, tarballs).

**Deployment check:** `https://plugins.omarchy.org/plugins.json`, `/all.json`, and `/config.json` each returned **HTTP 404, text/html** in this session. The installed CLI advertises Git installs only. These specs are not deployed APIs to hardcode as working today.

Migration: introduce an adapter for real deployed browse JSON, render all security notices and nullable fields, and delegate state changes to the official client after it ships. That client must own pinned signing roots, Ed25519 signatures, monotonic generations, expiry/freshness, SHA-256, compatibility, receipts and revocation handling. Do not implement partial verification in QML, and never use unsigned browse checksums as installation authority. Until then explicitly identify the current backend as mutable Git and the catalog as presentation metadata.

Retry endpoint verification:

```sh
for endpoint in plugins.json all.json config.json; do
  curl --silent --show-error --location --connect-timeout 8 --max-time 30 \
    --output /dev/null --write-out '%{http_code} %{content_type}\n' \
    "https://plugins.omarchy.org/$endpoint"
done
omarchy plugin --help
```

## Standard installation audit — 2026-09-06

The installed `omarchy-plugin-add` flow clones, validates, moves the checkout and requests a shell rescan, then optionally enables the plugin. It has no dependency installation or build-hook step. Additional manifest dependency fields would not cause package installation. This app therefore documents its native package requirements and builds its bundled decoder lazily after enable, rather than relying on installer hooks.

The manifest's `menu` kind denotes a summoned menu surface, not contributions to the stock menu. The stock menu combines defaults and user JSONC extensions; a standard overlay install does not create a launcher or Browse entry. Use `omarchy-shell shell summon webtechsponge.plugin-sea '{}'` after enabling. Project-managed menu/launcher setup belongs to the separate development installation, with backups and ownership checks.

`tests/standard-cli-install.sh` exercises the actual installed add/validate/catalog commands against an isolated local Git fixture, then invokes the cloned preview helper with real compilation and decoding. See [verification evidence](verification.md) for the test boundary and results.

## Permanent application identity

The approved application ID is now `webtechsponge.plugin-sea`, with author **webTechSponge** and an MIT license. Earlier session evidence may reference the former development ID `local.oma-plug-sea`; those historical observations remain valid for the platform contracts. The namespace change does not confer a verification badge.

Managed development installations must be uninstalled using the old checkout **before** its source is updated, then installed from the new checkout. Standard Git installations require backing up local edits, hiding/removing the old ID and installing the new ID; ordinary Git update does not migrate identity. CLI and cache/state identifiers are unchanged. See [README migration instructions](../README.md#migration-from-the-development-id).

## AI review launch contract — 2026-09-07

The active Omarchy command inventory (`omarchy commands --all --json`) contains 440 commands, including hidden commands, and no supported isolated verification runner. `omarchy agent --help --json` returns command metadata for a terminal launcher, not a verification-result or isolation-capability schema. The no-argument `omarchy default agent` getter reads the configured agent name only; it does not resolve a model/provider.

The installed `omarchy-agent` and its [platform upstream source](https://codeberg.org/malik-na/omarchy-mac/src/branch/quattro/bin/omarchy-agent) launch Codex with `--dangerously-bypass-approvals-and-sandbox`. The prompt wrapper delegates to that launcher; neither is used for Plugin Sea review. `omarchy-launch-tui` instead forwards an explicit command/argument array through `setsid uwsm-app -- xdg-terminal-exec`, without injecting agent permission flags.

The installed `codex --help` documents `--sandbox read-only`, `--ask-for-approval never` (failed requests are returned to the model rather than escalated), `--cd`, and `--search` (live web search without per-call approval). Plugin Sea uses those documented interactive options and leaves model/provider selection to Codex's user configuration. This implements the explicitly selected weaker advisory session, not the original snapshot-only/no-tools/no-network contract. Read-only shell policy does not confine all reads or configured integrations; no runtime enforcement audit was performed.
