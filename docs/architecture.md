# Architecture and contracts

The host is the existing Omarchy Quickshell process. `local.oma-plug-sea` is an overlay with `keepLoaded: true`, a root `open(payloadJson)` / `close()` contract, injected manifest and registry, and theme tokens from `qs.Commons` with shared `qs.Ui` controls. The local namespace deliberately identifies a development application; it claims neither the reserved Omarchy namespace nor an upstream publisher identity.

QML starts asynchronous `Quickshell.Io.Process` instances using argument arrays and resolves helpers relative to the injected manifest source directory. Search, filter, and sort context remain in memory across refreshes. Catalog/local correlation uses exact canonical IDs. Git update availability is unknown until a real update check; catalog versions are not a reliable installed revision comparison.

## Helper boundary

All helpers use Bash, jq and existing Omarchy system tools. JSON is returned on stdout. Operational failures return an `ok:false` envelope, so consumers must inspect `ok`, not just process exit status. Invalid invocation or unexpected helper failure can also produce a nonzero exit.

- `bin/oma-plug-sea-catalog refresh`: fetch live HTTPS metadata with bounded connection/total timeouts, normalize and atomically replace cache. A failed fetch or rejected document returns the saved catalog marked stale.
- `bin/oma-plug-sea-catalog cached`: return saved data with a stale indication, or an empty failure envelope on first launch without cache.
- `bin/oma-plug-sea-catalog normalize FILE`: deterministic schema adaptation for fixtures; timestamp uses the current clock.
- `bin/oma-plug-sea-local`: `{ok,error,plugins}` from `omarchy plugin list --json`, enriched with local manifest version, Git origin and default bar placement. No plugin code is imported by this helper.
- `bin/oma-plug-sea-action ACTION ID [SOURCE] [CONSENT]`: `{ok,action,id,error,stdout,stderr,plugins}`. Install and install-enable require SOURCE and `--consent-unsandboxed`. Enable/update require that flag; remove requires `--confirm-remove`; disable takes no extra argument.

The normalized catalog is `{schemaVersion:1,ok,source,fetchedAt,generatedAt,stale,error,plugins:[]}`. A row contains `id,name,description,author,version,category,tags,repo,previewImage,previewThumbnail,installAvailable,installNote,verificationStatus,verificationCoverage,verificationSnapshotStatus,listingValidatedCommit,upstreamObservedCommit,upstreamCheckStatus,stars,listedAt,status,sourceType,repositoryLayout,license`. Unsupported/malformed optional fields become conservative defaults. Broken required fields or duplicate IDs reject the document, preserving the good cache.

## Trust and mutations

Browse metadata never supplies a command. Sources are normalized canonical HTTPS GitHub repository URLs; mutable repository HEAD is not an authenticated reviewed artifact. The consent view identifies this mismatch and offers disabled installation first. The helper rechecks cached listing availability but that is only a usability gate, not code authentication. The installed Omarchy CLI owns Git cloning, manifest validation, placement, update and removal.

Actions serialize with `flock`, time out, back up existing shell.json, and verify post-action state. Install-and-enable performs disabled installation first, confirms the expected ID, then enables. A changed manifest ID fails confirmation and leaves the unexpected disabled checkout for inspection. Actions never claim success based solely on CLI stdout. The browser refuses to mutate itself so it cannot tear down its own in-flight process; use development uninstall tooling.

Before installing, dormant configured IDs that are absent from discovery cause a refusal: an unexpected cloned ID matching such a reference could otherwise auto-enable. The helper does not silently remove those references.

WebP previews use a strict fixed-origin curl fetch and a separate native Qt6 decoder (`lib/preview-decode.cpp`, built by `scripts/build-preview`). `qt6-imageformats` supplies WebP support; the shell receives only an atomic cached PNG. Input is limited to 8 MiB, dimensions to 8192 per side, Qt image allocation to 64 MiB, output to 1200 per side without upscaling, and only the first animation frame is decoded. Fresh output pixels discard source metadata. The wrapper imposes a 20-second wall timeout, 15-second CPU limit, 512 MiB address-space limit, 16 MiB output-file limit and disables core dumps. These are resource limits, not a sandbox. Existing cached previews work without redecoding. No ImageMagick executable or library is used.

The backend's lock coordinates its own actions, not unrelated terminal commands. Concurrent external changes can therefore fail a postcondition; the UI retains diagnostics and refreshes local state. No security audit or signed verification is claimed. Official signed installation must be delegated to a real official client when deployed, not reimplemented from aspirational API specifications.

## Integration

`mise run install` validates and stages a runtime copy, serializes integration, preserves previous managed copies in XDG state, backs up user files, inserts one marked JSONC menu property, rescans and waits for discovery before enabling. The installed host currently hardcodes `$HOME/.config/omarchy`; only cache/state follow XDG variables. A copy is intentional because Omarchy's CLI validator rejects symlinks. No package-owned file is edited. Integration can be removed with `mise run uninstall` while the shell is running.

## Source change checks

`bin/oma-plug-sea-catalog check` returns `{ok,refreshNeeded,error,checkedAt}` without replacing the catalog cache. Successful refreshes record `sourceValidators` (`etag`, `lastModified`) and a raw source SHA256 `sourceHash`. Checks use bounded conditional HEAD requests; older caches or servers without useful validators fall back to a bounded fetch and comparison. Network or malformed-response failures remain failures, never evidence of an update.

The UI checks on reopen and every five minutes while visible. Its initial empty load refreshes first. A detected change highlights **Refresh available**; only explicit refresh applies new rows. Polling, refreshes and mutations are serialized, with generation checks preventing obsolete poll results from overriding a refresh. Previously detected changes remain indicated if a later poll fails.

The published source currently advertises a ten-minute HTTP cache lifetime; polling reports the version served by that source/CDN.

## Full-size preview viewer

Detail previews open a modal native `ImageViewer` with fit-to-window, native dimensions, zoom and a scrollable/draggable image. The underlying page is disabled while the viewer is open; Escape/Close restores focus to the preview without changing search or selection. `PreviewImage.fullResolution` requests `oma-plug-sea-preview URL original`, which uses a separate `-original.png` cache entry and preserves dimensions instead of applying the 1200-pixel thumbnail limit. All input, allocation, dimension, process and output-file limits still apply; oversized or failed images display an error rather than bypassing the decoder boundary. Full-size animation previews still show the first frame.
