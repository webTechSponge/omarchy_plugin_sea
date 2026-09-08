# Architecture and contracts

The host is the existing Omarchy Quickshell process. `webtechsponge.plugin-sea` is an overlay with `keepLoaded: true`, a root `open(payloadJson)` / `close()` contract, injected manifest and registry, and theme tokens from `qs.Commons` with shared `qs.Ui` controls. The permanent author namespace is `webtechsponge`, with manifest author **webTechSponge** and an MIT license. It does not claim the reserved `omarchy.*` namespace or imply registry verification.

QML starts asynchronous `Quickshell.Io.Process` instances using argument arrays and resolves helpers relative to the loaded QML entrypoint directory. Search, filter, and sort context remain in memory across refreshes. Catalog/local correlation uses exact canonical IDs. Git update availability is unknown until a real update check; catalog versions are not a reliable installed revision comparison.

## Helper boundary

The catalog, engagement, local-state, action and preview helpers use Bash, jq and existing Omarchy system tools, returning JSON on stdout. The internal decoder builder instead prints an executable path on success and diagnostics on stderr with a nonzero exit on failure. Operational failures from the JSON helpers return an `ok:false` envelope, so consumers must inspect `ok`, not just process exit status. Invalid invocation or unexpected helper failure can also produce a nonzero exit.

- `bin/oma-plug-sea-catalog refresh`: fetch live HTTPS metadata with bounded connection/total timeouts, normalize and atomically replace cache. A failed fetch or rejected document returns the saved catalog marked stale.
- `bin/oma-plug-sea-catalog cached`: return saved data with a stale indication, or an empty failure envelope on first launch without cache.
- `bin/oma-plug-sea-catalog normalize FILE`: deterministic schema adaptation for fixtures; timestamp uses the current clock.
- `bin/oma-plug-sea-local`: `{ok,error,plugins}` from `omarchy plugin list --json`, enriched with local manifest version, Git origin and default bar placement. No plugin code is imported by this helper.
- `bin/oma-plug-sea-build-preview [--development]`: compile the bundled C++ decoder into private XDG cache, or prepare `lib/preview-decode` for development. Stdout is the executable path, not JSON. Build dependencies are checked before compilation.
- `bin/oma-plug-sea-preview URL [original]`: validate the fixed-origin URL, return an existing cached PNG or prepare the decoder and download/convert under resource limits; `{ok,path,error}`.
- `bin/oma-plug-sea-action ACTION ID [SOURCE] [CONSENT]`: `{ok,action,id,error,stdout,stderr,plugins}`. Install and install-enable require SOURCE and `--consent-unsandboxed`. Update requires the approved installed SOURCE and that flag; enable requires the flag; remove requires `--confirm-remove`; disable takes no extra argument.
- `bin/oma-plug-sea-engagement refresh|cached`: fetch and normalize anonymous engagement stats from the marketplace engagement API, atomically caching the hearts map. A failed fetch or rejected document returns the saved hearts marked stale with `ok:false`. `heart ID` sends one consented anonymous heart event (exact `{"pluginId","type":"heart"}` body, `Origin: https://plugins.omarchy.org`); `hearts-state` reports this computer's sent-heart record.
- `bin/oma-plug-sea-review capabilities`: `{ok,available,agent,error}` after the read-only `omarchy default agent` getter and executable presence checks. Only configured Codex is supported; missing/unsupported defaults fail closed without an agent/model fallback.
- `bin/oma-plug-sea-review launch ID SOURCE AGENT --consent-advisory-review`: validate the GitHub source, ID, consent and unchanged default; request a terminal via `omarchy launch tui`, returning `{ok,available,agent,error}` for the launcher, never an AI verdict. The terminal invokes the helper's internal `session` mode with the same arguments and rechecks the default before invoking Codex.

The normalized catalog is `{schemaVersion:1,ok,source,fetchedAt,generatedAt,stale,error,plugins:[]}`. A row contains `id,name,description,author,version,category,tags,repo,previewImage,previewThumbnail,installAvailable,installNote,verificationStatus,verificationCoverage,verificationSnapshotStatus,listingValidatedCommit,upstreamObservedCommit,upstreamCheckStatus,stars,listedAt,status,sourceType,repositoryLayout,license`. Unsupported/malformed optional fields become conservative defaults. Broken required fields or duplicate IDs reject the document, preserving the good cache.

The normalized engagement document is `{schemaVersion:1,ok,source,fetchedAt,stale,error,hearts:{}}` with `hearts` mapping canonical plugin IDs to nonnegative integers. It is cached at `oma_plug_sea/engagement.json` under `engagement.lock` with the same atomic-replace and stale-fallback discipline as the catalog. Only hearts are carried; views and copies are intentionally omitted until a later task needs them (D3, YAGNI). Counts are floored to finite nonnegative integers, malformed entries become 0, and non-canonical or prototype-like IDs (for example `__proto__`) are dropped so no hostile key reaches UI rows. A literal "—" means the API reported no record for that ID.

## Trust and mutations

Browse metadata never supplies a command. Sources are normalized canonical HTTPS GitHub repository URLs; mutable repository HEAD is not an authenticated reviewed artifact. The consent view identifies this mismatch and offers disabled installation first. The helper rechecks cached listing availability but that is only a usability gate, not code authentication. The installed Omarchy CLI owns Git cloning, manifest validation, placement, update and removal.

Actions serialize with `flock`, time out, back up existing shell.json, and verify post-action state. Install-and-enable performs disabled installation first, confirms the expected ID, then enables. A changed manifest ID fails confirmation and leaves the unexpected disabled checkout for inspection. Actions never claim success based solely on CLI stdout. The browser refuses to mutate itself so it cannot tear down its own in-flight process; remove a standard Git installation through the terminal with `omarchy plugin remove webtechsponge.plugin-sea`, or use `mise run uninstall` for the managed development copy.

Before installing, dormant configured IDs that are absent from discovery cause a refusal: an unexpected cloned ID matching such a reference could otherwise auto-enable. The helper does not silently remove those references.

All remote previews are restricted to the marketplace’s WebP asset URLs in both normalization and the QML component, including old cached catalogs. Unsupported formats and origins show a fallback; no remote URL is assigned to QML Image. Accepted previews use a strict fixed-origin curl fetch and a separate native Qt6 decoder (`lib/preview-decode.cpp`, built automatically by `bin/oma-plug-sea-build-preview` for standard installs, or by `scripts/build-preview` during development setup). `qt6-imageformats` supplies WebP support; the shell receives only an atomic cached PNG. Input is limited to 8 MiB, dimensions to 8192 per side, Qt image allocation to 64 MiB, default thumbnail output to 1200 per side without upscaling (original-size mode preserves dimensions), and only the first animation frame is decoded. Fresh output pixels discard source metadata. The wrapper imposes a 20-second wall timeout, 15-second CPU limit, 512 MiB address-space limit, 16 MiB output-file limit and disables core dumps. These are resource limits, not a sandbox. Existing cached previews work without redecoding.

The backend's lock coordinates its own actions, not unrelated terminal commands. Concurrent external changes can therefore fail a postcondition; the UI retains diagnostics and refreshes local state. No security audit or signed verification is claimed. Official signed installation must be delegated to a real official client when deployed, not reimplemented from aspirational API specifications.

## Development integration

`mise run install` validates and stages a runtime copy, serializes integration, preserves previous managed copies in XDG state, backs up user files, inserts one marked JSONC menu property, rescans and waits for discovery before enabling. The installed host currently hardcodes `$HOME/.config/omarchy`; only cache/state follow XDG variables. A copy is intentional because Omarchy's CLI validator rejects symlinks. No package-owned file is edited. Integration can be removed with `mise run uninstall` while the shell is running.

## Source change checks

`bin/oma-plug-sea-catalog check` returns `{ok,refreshNeeded,error,checkedAt}` without replacing the catalog cache. Successful refreshes record `sourceValidators` (`etag`, `lastModified`) and a raw source SHA256 `sourceHash`. Checks use bounded conditional HEAD requests; older caches or servers without useful validators fall back to a bounded fetch and comparison. Network or malformed-response failures remain failures, never evidence of an update.

The UI checks on reopen and every five minutes while visible. Its initial empty load refreshes first. A detected change highlights **Refresh available**; only explicit refresh applies new rows. Polling, refreshes and mutations are serialized, with generation checks preventing obsolete poll results from overriding a refresh. Previously detected changes remain indicated if a later poll fails.

The published source currently advertises a ten-minute HTTP cache lifetime; polling reports the version served by that source/CDN.

## Engagement stats

Hearts come from the marketplace's separate engagement API (`https://api.omarchyplugins.com/v1/stats`), never from `catalog.json`. `bin/oma-plug-sea-engagement` applies the same lock/atomic/stale-fallback discipline as the catalog helper and writes `oma_plug_sea/engagement.json`. The UI refreshes engagement alongside catalog refreshes but independently of catalog health: an engagement failure never blocks the catalog and never marks it stale. On failure the helper returns the last saved hearts with `ok:false` and `stale:true`; the UI keeps showing those cached hearts (falling back to the previous in-memory map when no cache exists) and reports the condition on the status line. Cards and details render the count, and sorting by hearts treats plugins without an engagement record as lowest so untracked plugins sort last in descending order.

Hearts are anonymous aggregate interactions reported by the omarchyplugins.com marketplace — not downloads, installs, unique people, or safety signals. The UI displays hearts only (D3). Sending a heart (Phase B) POSTs exactly one `{"pluginId","type":"heart"}` event to `https://api.omarchyplugins.com/v1/events` after explicit consent, and never sends view/copy events (D2). The request carries `Origin: https://plugins.omarchy.org` (D1, disclosed in the consent text); the marketplace rate-limits hearts and records no account or identity. The helper validates the ID locally, refuses repeats via a per-computer hearted record at `oma_plug_sea/hearts.json` (queried with `hearts-state`), and maps 202-recorded / rate-limit / 429 / transport outcomes to honest envelopes. The UI applies the change optimistically, lets the server total win on success, and rolls back on failure; a heart never touches install, enable, or verification state.

## Full-size preview viewer

Detail previews open a modal native `ImageViewer` with fit-to-window, native dimensions, zoom and a scrollable/draggable image. The underlying page is disabled while the viewer is open; Escape/Close restores focus to the preview without changing search or selection. `PreviewImage.fullResolution` requests `oma-plug-sea-preview URL original`, which uses a separate `-original.png` cache entry and preserves dimensions instead of applying the 1200-pixel thumbnail limit. All input, allocation, dimension, process and output-file limits still apply; oversized or failed images display an error rather than bypassing the decoder boundary. Full-size animation previews still show the first frame.

## Application branding

The transparent version 4 artwork, derived from the approved version 3 design, lives in `assets/branding/`. The browse header displays the PluginSea wordmark; detail pages show the matching wave-and-plug icon. Both PNGs have real alpha transparency and a subtle navy contour/shadow to preserve legibility across light and dark themes. Both expose the accessible name Omarchy Plugin Sea, and the header retains a text fallback if the wordmark cannot load. Existing manifest, commands and storage identifiers are unchanged. The development installer ships only the approved PNG pair; earlier design iterations and generation notes remain in the source repository.

## Reviewed source identity

The consent view deep-copies its selected row so later local/catalog refreshes cannot alter the approved source. Update calls pass that installed origin explicitly. The backend compares it with refreshed local metadata and rechecks the effective Git fetch URL immediately before invoking Omarchy, including URL rewrites and ambiguous multiple origins. The upstream CLI accepts only an ID, so this precondition is not atomic with its fetch: external Git configuration changes can still race it.

ID correlation identifies local state only. Source links for installed plugins use their actual local origin and never fall back to the catalog. HTTPS and standard GitHub SSH spellings are canonicalized for presentation comparison; catalog snapshot verification is kept distinct from installed-code verification. Missing or differing origins receive explicit provenance notes. Non-string optional status values normalize successfully but disable installation for that listing.

## Local read ordering and lifecycle warnings

LocalStateCoordinator owns each asynchronous local read through its deferred completion. Starting a mutation increments a generation and invalidates outstanding reads. Mutation completion applies the helper's checked result and schedules a fresh local read; if the older process is still active, its result is discarded before the new read starts. Old successes and failures cannot replace post-action state. The Qt model suite exercises both completion orders using the actual coordinator.

Catalog lifecycle warnings are separate from local enabled/disabled state and code verification. Quarantined, yanked and unavailable listings retain warnings on cards, in details and in consent even when installed. A source mismatch scopes the warning to the same-ID catalog listing. Disable and remove remain available; enabling/updating still requires explicit consent.

Installation resolves the approved Git URL locally with ls-remote --get-url before invoking add, rejecting URL rewrites. The disabled checkout must then have the expected manifest ID and a single matching raw and effective origin before success or enable. As with updates, these preconditions cannot make an upstream CLI operation atomic against unrelated local configuration changes.

## Runtime verification identity

Development installation places the shipped files under runtime/<SHA256>/ and points the outer manifest's overlay entrypoint there. The hash covers runtime file paths, contents and permissions, including the native decoder and approved branding; the installed root QML contains the hash as a literal exposed through status. Build-specific paths also give imported QML/JavaScript and assets unique URLs, preventing an older component cache from mixing into a new build. The stable plugin ID, launcher command and cache/state directories do not change.

For managed development installations, scripts/verify-runtime checks checkout ownership, the outer manifest, installed files, embedded stamp and live QML status. Desktop smoke and keyboard scripts require this check; each keyboard invocation also confirms the overlay remains open. Isolated integration tests deliberately substitute stale files, a different checkout marker and an old in-memory fingerprint and require rejection. The fingerprint identifies a development build; it is not a signature or a security guarantee about plugin code.

## Standard source installation

A normal omarchy plugin add/enable installation loads the root QML directly and needs no development setup. When no prepared decoder exists, oma-plug-sea-preview invokes the bundled builder before downloading an accepted preview. The builder compiles only lib/preview-decode.cpp; it neither downloads code nor installs packages. Required gcc/pkgconf/Qt packages are documented separately because Omarchy has no dependency or build-hook manifest contract.

Standard builds live under the private XDG cache at oma_plug_sea/decoder-builds/<signature>/, keyed by source, builder, compiler and Qt metadata. A 75-second lock wait serializes builds, compilation has a 60-second timeout plus a five-second kill grace, codec validation has a ten-second timeout, and atomic publication occurs only after success. The checkout stays untouched. These trusted-source build limits are separate from the tighter untrusted-image decoder limits above. Existing image-cache hits need no compiler. Development installations retain their prepared binary and content-fingerprint checks. Missing dependencies/build failures return actionable errors displayed on detail pages; preparing previews shows a loading message.

Standard overlays open through the supported shell summon IPC; the stock installer does not generate launchers or menu extensions. The managed development workflow is separate and supplies its own launcher/Browse entry. Root preview.png is the marketplace screenshot and the README's image source.

When refreshing listing screenshots, update both `docs/screenshots/browser-transparent-logo.png` and the root `preview.png`; README uses the root file and historical verification links use the docs path. Keep the two current screenshot files byte-identical.

## Plugin ID migration

The application moved from development ID `local.oma-plug-sea` to permanent ID `webtechsponge.plugin-sea`. CLI names and `oma_plug_sea` cache/state identifiers stay stable; the inert test fixture remains `local.oma-plug-sea-smoke`. Identity comparisons, self-mutation protection, installed directories and shell IPC use the permanent ID.

Migration is explicit: uninstall a managed development copy with the old checkout's scripts **before updating that checkout**, then install from the new source. For standard Git installs, back up local edits, hide and remove the old ID through Omarchy, then install the new ID. Updating an old checkout in place does not migrate its directory or shell configuration. See the [migration commands](../README.md#migration-from-the-development-id).

## Advisory AI review

This is a user-approved advisory terminal launcher, not a substitute implementation of the unavailable isolated verification runner. QML checks the default on open, deep-copies the selected row for consent and supplies its canonical source plus the approved agent. Installed entries use their installed origin; missing origins never fall back to the catalog. Only canonical GitHub sources and validated IDs reach the prompt; catalog names, descriptions and upstream instructions do not supply executable arguments.

The session starts Codex in a new mode-0700 empty temporary directory, removed when the session command exits, using `--sandbox read-only --ask-for-approval never --search`. There is no model, provider or profile override. It does not use `omarchy agent` or automatic-approval flags. Source acquisition is left to the prompted agent's read-only GitHub web/API access; Plugin Sea neither clones nor downloads target code. The prompt requests one identified commit, evidence-backed findings and explicit coverage limits, and forbids execution, tests, builds, installation, local private-file access and MCP use.

The UI explicitly discloses that shell read-only mode does not restrict reads to a source snapshot or sandbox configured integrations. Prompt prohibitions are advisory, not enforcement. Codex's user-level configuration and provider handle model selection, integrations, authentication and history. Live web access is intentionally enabled. No structured AI-result parser, verdict cache, verification badge, install authorization or automatic review deadline is claimed. Cancellation and subsequent interaction belong to the user in the terminal; browser close is not cancellation.

Review has its own subprocess ownership and status text. Its launch completion never calls the mutation helper, replaces local-state results or overwrites lifecycle diagnostics. A successful launcher exit is not evidence that the review completed or that the source is safe. Existing install/update/remove consent, source checks, locks and postconditions are unchanged. Runtime-copy installation/fingerprinting already includes the new helper through the existing `bin/` inclusion.
