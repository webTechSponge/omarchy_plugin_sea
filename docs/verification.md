# Verification — 2026-09-05

Completed on the installed Omarchy desktop: one 2560×1600 display at scale 2 (1280×800 logical), Qt6 6.11.2, existing running Quickshell. No community plugin was installed to prove lifecycle behavior.

| Check | Result |
|---|---|
| `mise run setup` | Native dependencies and shell ping pass |
| `omarchy plugin validate .` | Pass |
| Bash syntax for every helper/script/test | Pass |
| `mise run check` | Pass: backend, actual Qt6 JS model, preview and isolated integration suites |
| Backend behavior/security | 43 assertions pass |
| Actual Qt6 CatalogModel tests | 13 assertions pass |
| Preview behavior/security | Decode, cached reuse, strict URL boundary, malformed data, resize, concurrent conversion pass |
| Isolated integration | Async registry discovery, repeated install/uninstall, byte-identical JSONC roundtrip, backups, unowned target and dangling-symlink rejection pass |
| Basic `qmllint` | Pass |
| Qt6 `qmllint` with host alias imports | Exit 0; 67 advisory warnings for Quickshell creatability/type metadata, dynamic theme objects and unqualified component access. Runtime was checked separately |
| `mise run smoke` | Actual summon/hide and inert local panel enable/disable/remove postconditions pass; fixture removed |
| `scripts/keyboard-smoke` | Search, arrows, Enter, details, Escape/back, empty search result and closing pass |
| Mouse input | Real Wayland pointer card activation, install-consent opening/cancellation, state/sort/category selection and menu Browse activation pass |
| Live catalog | 2,427 remote rows normalized; browser shows 2,429 rows including two local-only plugins |
| Real network failure | Dead localhost HTTPS proxy returns 2,427 last-known-good rows, `ok:true,stale:true`, preserved timestamp and curl error |
| Visual inspection | 1120×748, 760×620, and 620×480 logical surfaces; readable themed layout, working image previews/fallbacks, scrollable details/consent, reachable action buttons |
| Final shell logs | No browser QML warnings, exceptions or image decoder errors after fixes. One existing host portal app-ID registration warning is unrelated |
| Repository review | No credentials, caches, third-party implementation downloads, developer-only runtime paths, symlinks or shell evaluation in shipped runtime; required files tracked; whitespace checks pass |

## Visual evidence

The images below are actual captured browser surfaces, cropped at capture time so unrelated desktop content is excluded.

![Native browser with live previews](screenshots/browser.png)

[Compact browser](screenshots/compact.png) · [Full consent](screenshots/consent.png) · [Compact scrollable consent](screenshots/compact-consent.png)

Mouse input used a temporary Wayland virtual pointer client built against the installed Wayland libraries from the primary wlr protocol. It was used only for observed coordinates on this session's display and is not a product dependency.

## Exact retry commands

```bash
mise run check
mise run smoke
scripts/keyboard-smoke
omarchy-shell shell summon local.oma-plug-sea '{"width":620,"height":480}'
omarchy-shell shell call local.oma-plug-sea status '{}'
quickshell log -p "$OMARCHY_PATH/shell" -t 100 --no-color

# A real transport failure without changing network or desktop configuration:
HTTPS_PROXY=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9 \
  bin/oma-plug-sea-catalog refresh | jq '{ok,stale,error,fetchedAt,count:(.plugins|length)}'
# Recover using the normal endpoint:
bin/oma-plug-sea-catalog refresh | jq '{ok,stale,error,count:(.plugins|length)}'
```

The installed Qt lacks optional WebP support. `omarchy pkg add qt6-imageformats` could not authenticate noninteractively, so no package was installed. This is resolved by the tested bounded ImageMagick conversion path using an already installed dependency; normal previews work.

The official signed registry endpoints remain unavailable (404), as recorded in platform research. Current catalog and Git management work; signed artifact installation cannot be supplied by this installed platform. Git update availability remains unknown until checked, and mutable HEAD can differ from reviewed metadata. These are explicit product limitations, not claimed verification guarantees.

## Naming update

The repository directory is now `omarchy_plugin_sea`; the manifest and interface display **Omarchy Plugin Sea**. Existing command, plugin ID and storage paths remain stable. The local installation and ownership marker were rebuilt from the new directory with recoverable configuration backups.

## Source polling update

The current suite passes 43 backend assertions, including 14 source polling cases: saved validators, unchanged HTTP 304, equal/changed ETags, Last-Modified, missing validators, old cache, unsupported HEAD fallback, malformed bodies and network/HTTP failures. Every check preserves the catalog cache byte-for-byte.

A real desktop test temporarily replaced only the saved ETag with a controlled old marker (with a timestamped backup), called `omarchy-shell shell call local.oma-plug-sea pollCatalog '{}'`, and verified **Refresh available** while the visible `weather` search stayed at 31 results. F5 fetched current data, cleared the indication and preserved the search. The actual current validators were restored through successful refresh. The unchanged live source reports `refreshNeeded:false`.

![Detected source change without replacing visible results](screenshots/refresh-available.png)
