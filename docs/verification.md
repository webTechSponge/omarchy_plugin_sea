# Verification

The initial implementation results below are a historical baseline from 2026-09-05. Later dated sections record subsequent changes; current review results are recorded at the end.

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

![Current branded browser](screenshots/browser-transparent-logo.png)

[Compact browser](screenshots/branded-compact.png) · [Full consent](screenshots/consent.png) · [Compact scrollable consent](screenshots/compact-consent.png)

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

WebP previews use an isolated native Qt helper. `qt6-imageformats` 6.11.2-1 was installed successfully through terminal authentication. `mise run setup` builds the helper and verifies codec support; `mise run check` passes with the installed Qt plugin. The expanded preview suite covers cached reuse, concurrency, strict URLs, malformed/truncated/foreign input, byte and dimension limits, transparency, first animation frame, metadata stripping, resizing and extreme thin images. A negative sentinel confirms the retired conversion command is never invoked.

Qt 6.11 rejects some valid WebPs shorter than its header probe. The helper pads only complete tiny RIFF containers outside their declared contents; truncated containers remain rejected. Regression fixtures cover both cases. A live marketplace preview decoded successfully into an isolated fresh cache. After a recoverable development reinstall, a fresh desktop preview cache populated through the new helper and visual checks passed at 1120×748 and 620×480. Logs showed no preview/QML errors; existing host portal/status-notifier warnings are unrelated.

[Browser with Qt-decoded previews](screenshots/qt-previews.png). Keyboard smoke checks also pass. Previously cached images were retained after verification for offline reuse.

The official signed registry endpoints remain unavailable (404), as recorded in platform research. Current catalog and Git management work; signed artifact installation cannot be supplied by this installed platform. Git update availability remains unknown until checked, and mutable HEAD can differ from reviewed metadata. These are explicit product limitations, not claimed verification guarantees.

## Naming update

The repository directory is now `omarchy_plugin_sea`; the manifest and interface display **Omarchy Plugin Sea**. Existing command, plugin ID and storage paths remain stable. The local installation and ownership marker were rebuilt from the new directory with recoverable configuration backups.

## Source polling update

The source-polling implementation passed 43 backend assertions at that stage, including 14 source polling cases: saved validators, unchanged HTTP 304, equal/changed ETags, Last-Modified, missing validators, old cache, unsupported HEAD fallback, malformed bodies and network/HTTP failures. Every check preserves the catalog cache byte-for-byte.

A real desktop test temporarily replaced only the saved ETag with a controlled old marker (with a timestamped backup), called `omarchy-shell shell call local.oma-plug-sea pollCatalog '{}'`, and verified **Refresh available** while the visible `weather` search stayed at 31 results. F5 fetched current data, cleared the indication and preserved the search. The actual current validators were restored through successful refresh. The unchanged live source reports `refreshNeeded:false`.

![Detected source change without replacing visible results](screenshots/refresh-available.png)

## Full-size viewer

Detail images now open a native image viewer by mouse click or Enter/Space. Live verification opened the 2048 listing's original 1600×836 image, confirmed the original dimensions through shell status, switched to 100% and 125% zoom, returned with Escape, reopened using restored keyboard focus, and closed through the mouse control without leaving the detail page. Fit layout was visually inspected at 1120×748 and 620×480. [Full-size viewer screenshot](screenshots/full-size-preview.png).

`mise run check` passes, including original-size cache separation/offline reuse and invalid-mode/dimension rejection. Qt6 static analysis exits 0 with 90 host/dynamic-type advisory warnings; the running shell logs contain no viewer/QML errors. The existing portal registration warning remains unrelated.

## Approved branding — 2026-09-06

The approved PluginSea wordmark is rendered in the browse header, with a shorter header on compact surfaces; detail pages show the matching icon. Plain-text accessibility names and an image-error text fallback preserve the application name. The development installer includes only the approved artwork pair, verified byte-for-byte by the isolated integration test.

`mise run check` passed. After the compact-height adjustment, QML static analysis and real keyboard smoke checks passed. Visual checks at 1120×748 and 620×480 confirmed readable branding, reachable controls and the detail-page icon. The shell was restarted to clear cached QML; its fresh logs contain no branding/image errors.

[Branded browser](screenshots/browser-transparent-logo.png) · [Compact browser](screenshots/branded-compact.png) · [Detail icon](screenshots/branded-detail.png)

## Source review and documentation audit — 2026-09-06

All three findings against initial commit dc778ef also applied to the current implementation. Updates now carry the consent snapshot's approved origin and reject changed, rewritten or ambiguous origins before any CLI update. Installed source links and provenance labels distinguish forks and missing origins from catalog metadata; matching repositories still do not authenticate the installed revision. Non-string optional statuses no longer invalidate a complete catalog and instead disable installation for that row. Available filtering now excludes manual-only listings.

`mise run check` passes: 57 backend behavior/security assertions, expanded actual Qt6 model/source-provenance assertions, preview tests and isolated integration checks. Qt6 static analysis exits successfully with 115 host/dynamic-type advisory warnings. The installed app was refreshed and visually checked; its source-review consent shows the fork origin and explicit catalog-verification mismatch.

A locally authored inert panel using the catalog ID terminal.2048 was discovered disabled with a different Git origin. Native update consent showed that installed origin. Changing the origin and refreshing local state left the consent text byte-identical; passing its old source to the real helper returned a changed-origin refusal before the CLI update. No remote fetch or code enable occurred. The fixture was moved to recoverable user state and its disappearance from plugin discovery was confirmed. [Consent evidence](screenshots/source-review-consent.png).

The Omarchy CLI has no atomic expected-origin parameter, so an external Git-config edit can still race the final precondition check and the CLI fetch. This limitation is documented rather than presented as full protection against concurrent same-user changes.

The README now uses the current branded screenshot and lists the Qt build/check packages, ripgrep and optional keyboard-test dependency. Obsolete conversion references were removed from current user documentation; historical screenshots and original verification results remain explicitly identified as earlier evidence. Action argument documentation, source identity rules, original-image size limits and symlink-discovery wording were also audited and corrected.

## Boundary and verification review — 2026-09-06

All six new findings were valid and addressed:

- Every remote preview now passes both a fixed-origin WebP allowlist and the separate restricted downloader/decoder. A real headless Quickshell test feeds normalized listings and legacy cached URLs into the production PreviewImage component, including PNG/JPEG, foreign WebP, traversal and extensionless URLs; only the approved image reaches the downloader and QML receives only a local PNG.
- Installation rejects Git insteadOf rewrites before add. Real Git regressions cover both local-file and different-GitHub-repository rewrites with no add/enable calls. Post-install manifest and raw/effective-origin checks refuse enabling an unexpected checkout.
- The production local-state coordinator discards pre-mutation success/error results and requires a fresh read. Qt tests deliberately reverse read/mutation completion order and exercise both orderings.
- Installed state no longer hides quarantined, yanked or unavailable catalog warnings. Model tests cover enabled/disabled state, extended status text and fork association. Details and consent render the warning independently; recovery actions remain available.
- Each installed build uses a SHA256-specific runtime path, including imported components. Desktop tests check installed bytes, checkout ownership and the live embedded fingerprint; isolated regressions reject stale files, stamps and live status.
- The headless model runner clears inherited platform themes. The exact reported environment, QT_QPA_PLATFORMTHEME=gtk3, now passes without a display connection.

mise run setup and mise run check pass: 61 backend assertions, expanded Qt model/coordinator assertions, the actual catalog-to-QML preview boundary, decoder tests and isolated installation tests. Qt6 static analysis succeeds with 130 advisory host/dynamic-type warnings. After installing the new build, mise run smoke passes real summon/hide and controlled inert enable/disable/remove transitions; scripts/keyboard-smoke passes search, arrows, details, Escape and empty-state checks. Both require the current runtime fingerprint. The fixture was removed successfully.

The running current build was visually inspected at 1120×748 and 620×480, with live catalog previews and 2,540 correlated listings. Shell logs show no new QML/runtime errors; the earlier host portal registration warning remains unrelated. The live catalog contained no quarantined/yanked listings, so lifecycle edge cases are covered by deterministic model fixtures rather than claimed as live-catalog observations.

Git source checks still cannot be atomic against unrelated same-user configuration edits during upstream CLI operations. Unsupported preview formats/origins intentionally display a fallback; this is now consistent across normalization, old caches and QML.

## Transparent branding — 2026-09-06

Version 4 removes the original navy matte through user-approved local Qt image processing, preserving the version 3 artwork. Both outputs are RGBA PNGs with more than one million fully transparent pixels each and partially transparent antialias/shadow edges. A thin navy contour and tight soft shadow preserve cream/cyan contrast on light backgrounds. Dark navy, white and pale blue composites were visually inspected; no simulated checkerboard asset is shipped.

`mise run check` passes, including installed asset equality and runtime fingerprint checks. The managed installation was refreshed, its live fingerprint verified, and the actual header inspected without the old rectangle. Keyboard smoke passes. The README screenshot and artwork references now use the transparent version. The reproducible preparation tool is development-only and adds no app dependency or runtime effect.

## Listing explanations and stars — 2026-09-06

Cards now show catalog repository star counts beside their titles; local-only entries display a dash. The existing descending-star sort is explicitly labelled “Stars: high to low.” Actual Qt model tests compare multiple candidates and cover malformed/negative/fractional counts. Availability, catalog verification and stars have themed, wrapped, plain-text hover explanations; tooltip content is positioned above the corresponding label.

`mise run check` passes (134 advisory QML warnings). After the final tooltip placement adjustment, QML/model checks and keyboard smoke pass. The installed runtime fingerprint was verified. Live mouse checks exercised both availability and catalog tooltips, selected star sorting, confirmed descending visible counts and opened a card. The listing was visually inspected at 1120×748 and 620×480; the README screenshot was refreshed.

## Separate sorting direction — 2026-09-06

The sort field dropdown now contains name, stars and date; a separate keyboard-focusable ↑/↓ button controls ascending/descending direction and retains it when the field changes. Its accessible name and hover explanation describe the current direction. Qt model tests cover both directions for all three fields. `mise run check` passes (136 advisory QML warnings); the installed runtime fingerprint and keyboard smoke pass. Live mouse checks toggle direction both ways, change fields without resetting direction, and confirm the resulting status. The compact 620×480 layout was visually checked; the README screenshot now shows the independent control.

## Standard Git installation and marketplace preview — 2026-09-06

Standard source installations now build the bundled Qt preview decoder automatically into a private XDG cache on first uncached preview. The cache signature covers source, builder and native toolchain; no build occurs in the checkout and no source/executable is downloaded. Dependencies are documented as packages to install before using Omarchy's normal add/enable command. The standard opening route is shell summon IPC; Omarchy has no manifest build/dependency hooks or automatic overlay menu contributions. The development launcher/menu workflow remains separate.

`mise run check` passes, including a new test through the actual installed Omarchy add/validate/catalog commands with an isolated HOME and local Git fixture. Only shell IPC and preview download are mocked; cloning, validation, native compilation and image decoding are real. The installed tree stays disabled and clean, with no generated binary or user-menu/config changes. A separate read-only source-tree test confirms one build for concurrent previews, cache reuse, source-change invalidation, missing-dependency guidance, failed-build atomic cleanup and successful retry without mise. QML analysis passes with 137 advisory warnings. The managed desktop installation was refreshed and keyboard smoke passes.

`preview.png` at the repository root is the current transparent-branding screenshot (2240×1496, under 1 MB), ready for marketplace image ingestion. README now references it and documents standard installation, opening, updating and removal. Plugin ID and publication status are unchanged.

## Publisher identity migration — 2026-09-06

Changed the application ID from `local.oma-plug-sea` to `webtechsponge.plugin-sea`, set author to `webTechSponge`, and declared the existing MIT license in the manifest. Updated IPC routes, installation paths, self-mutation protection, runtime verification and current documentation; the launcher, caches and inert smoke fixture retain their identifiers.

`mise run check` passed, including 61 backend assertions, Qt model and preview suites, real isolated Git installation, automatic decoder build/recovery, and managed integration ownership/fingerprint/cleanup checks. QML lint passed with 137 existing advisory warnings. The real local migration used the old checkout's `mise run uninstall` before changing the scripts, followed by `mise run install` and `mise run smoke`. The current runtime fingerprint was verified; summon/hide and inert fixture enable/disable/remove passed. Registry inspection confirmed only the new application ID is discovered and enabled. The new ID's self-removal request was correctly rejected. Recent shell logs contained no QML errors. Recovery copies remain in the existing XDG state directory.

## Security hardening (findings 2–5) — 2026-09-06

Implemented `docs/security-hardening-plan.md` via three parallel edit units plus one single-writer test integration. Finding 1 (origin-check TOCTOU vs. external Git config) remains an accepted documented platform limitation.

- Installed-source buttons are GitHub-canonical or disabled: new `safeGitHubLink` in `js/CatalogModel.js`, raw-URL fallback removed from `PluginDetails.qml`, both source buttons gated. `safeLink` unchanged for the marketplace preview gate. Model tests cover foreign-origin rejection and SSH canonicalization.
- `bin/oma-plug-sea-local` skips symlinked `manifest.json`/`.git` entries; they contribute no metadata row.
- `bin/oma-plug-sea-catalog` and `bin/oma-plug-sea-preview` refuse non-absolute, symlinked or unowned cache dirs (catalog falls back to last-good stale; preview returns `ok:false`). Refresh-time `etag`/`lastModified` are CRLF-stripped and bounded before persist.
- `tests/backend.sh` gains symlinked-manifest, symlinked-`.git`, symlinked-cache and CRLF-ETag cases; `tests/preview.sh` gains a symlinked-cache refusal case.

`mise run check` passes, including 69 backend assertions (was 61), Qt model and preview suites, and managed integration checks. QML analysis passes with 140 existing advisory warnings.

## Marketplace agent-context finding — 2026-09-09

Removed the root `AGENTS.md` and its README link rather than relocating agent instructions within the installable repository. Standard Git installation clones the whole tree, so the development installer's runtime-only copy does not protect marketplace users. Existing README and architecture documentation retain the product, development and safety requirements; the ignored local `PROMPT.md` remains excluded from distribution.

The real Git installation regression now builds its disposable repository from current tracked files and non-ignored additions, omitting deleted files, instead of a runtime allowlist that concealed repository extras. It rejects common auto-loaded agent instruction filenames at any depth in the installed checkout and refuses to distribute the local execution brief or generated decoder.

Verification: `bash -n tests/standard-cli-install.sh`, `bash tests/standard-cli-install.sh`, and `omarchy plugin validate .` passed. The regression exercised real Omarchy add/validate/catalog in an isolated HOME, checked the installed tree, and compiled the native decoder and decoded a preview fixture. Shell IPC and preview download were mocked; no user desktop installation was changed.

This is local remediation, not marketplace revalidation or a full security review. After publishing a new commit, resubmit and validate that revision; the marketplace validation, decoded security baseline and current default-branch HEAD must all match its full SHA. The previously validated `6a56a20e112acf70a8d66e8164c1676145f04c7f` does not cover this fix. The deferred catalog/install/enable, cache/compiler, preview/network, engagement, URL and filesystem review remains outstanding.

## Immutable snapshot installation — 2026-10-04

Implemented the local remediation for [marketplace submission #5215](https://github.com/omacom/omarchy-plugin-marketplace/issues/5215) and its [unpinned-install/update review](https://github.com/omacom/omarchy-plugin-marketplace/issues/5215#issuecomment-5672438941). Community installation now binds consent to ID, canonical HTTPS repository and full reviewed SHA, fetches/checks out only that object detached in private hidden staging, statically validates it with Omarchy, and atomically publishes without overwrite or copy fallback. Both community enable paths recheck fresh eligible snapshot evidence, origin, detached HEAD, object integrity and literal clean contents. Mutable in-app update execution and UI callers are removed.

The live catalog's verified snapshot value is `verified`; `verificationCommit` must equal `listingValidatedCommit`. Root layout and manifest location are required. A newer observed upstream commit is not installed automatically. Unsigned catalog metadata remains unsigned, community code remains unsandboxed, and the application lock does not prevent arbitrary same-user modifications between checks and activation.

### Checks observed

- `scripts/check` passed: 64 backend behavior/security assertions, actual Qt6 model/provenance tests, initially 58 real-Git pinned-install assertions, preview boundary/decoder suites, actual platform self-install/native lazy-build regression, and managed-install ownership/fingerprint/integration checks. Qt6 analysis passed with 168 advisory host/dynamic-type warnings.
- Live smoke exposed an overbroad collision guard: an unrelated existing development symlink blocked all installation. Collision inspection now uses Omarchy's static catalog, leaving unrelated symlinks untouched while detecting duplicate IDs. The expanded `bash tests/pinned-install.sh` passed 60 assertions after that correction.
- `scripts/qml-check` passed again after the final external-guidance adjustment, with 168 advisory warnings.
- The managed runtime was installed with recoverable backups. `scripts/smoke-test` passed real summon/hide, local-only enable refusal, explicit external enable of an authored inert panel, then in-app disable/remove. `scripts/keyboard-smoke` passed search/arrows/Enter/details/Escape/empty-state interactions.
- The current runtime was verified with fingerprint `0ef0cdf00b056f54aad2a6f40807fc83cfb820c1fbf6a753bab3edbcf134a10b`.

### Real pinned lifecycle smoke

A throwaway locally authored Git repository contained reviewed A (`ac44bd739880c64cdc4f40ac287de9a21d663fc1`) and different upstream HEAD B (`7cbc64950a3f6e91cb159073484ed50411878384`). Only catalog download and Git network transport were substituted with that controlled fixture; Omarchy validation, discovery, rescan, enable, disable, removal and actual QML loading used the real running desktop shell.

The production action helper installed A detached and confirmed it disabled. Standalone enable succeeded, and the loaded inert panel's `revision` function returned `A`, never B. After disable and a tracked entrypoint modification, re-enable returned `ok:false` with the plugin still disabled. Production removal returned `ok:true` with no remaining discovered fixture. Temporary repositories, transport wrappers, pointer client and screenshots were removed; no arbitrary third-party plugin was enabled.

The permanent pinned regression uses real Git/validator/catalog but simulates network transport and shell enable state. It covers exact A versus B, identity/revision/content changes, untracked/ignored files, executable config, user-index flags, writable tracked files, stale/changed/missing evidence, exact-object fetch failure, unsafe paths/locks, dormant configuration, existing/concurrent destinations, development symlinks/duplicate IDs, retained post-publication failures and obsolete update refusal. Its simulated-shell limit is supplemented by the real-shell smoke above.

### Actual UI inspection

At 1120×748 logical size, the Overview install consent visibly named exact SHA `b09c227ba43182bebf101e5882147029fdddf7f1`, canonical repository, disabled-install choice, and unsigned/unsandboxed boundary; consent was cancelled without installing it. Lacuna's unsupported suite listing exposed its refusal and no install controls. The disabled authored Git fixture showed a disabled Enable button, actual installed SHA/detached/dirty state, no update button, and scrollable external-update guidance including disable-first/live-reload risk. A direct obsolete UI update request produced an unsupported-action message without opening consent or mutating code.

### Publication status

These are local implementation and runtime checks, not marketplace approval. Verification did not push code, apply approval labels, or create a new submission. Keep the finalized commit's full SHA/default-branch HEAD frozen, open a new submission referencing #5215, and obtain fresh matching validation and decoded security-baseline SHAs before requesting the current `approved-and-verified` review/publication path.

## Immutable install review remediation — 2026-10-04

Remediated all three findings against commit `9c9ea8217fd02ef46f50c8f20bcf88622a019cae` in [the post-commit review](immutable-install-review.md). The original reproduction results were treated as established evidence, not rerun before choosing fixes. The initial working tree contained the review file and its plan-status edit; both were retained and updated in place.

### Implemented boundary

- **P1 selected source:** enumerate raw third-party top-level manifests before ID deduplication, preserve unrelated development symlinks/hidden staging semantics, and require exactly one candidate at the canonical reviewed checkout. The backend additionally inspects the running registry's selected `__sourceDir` through the updated, loaded browser's `activationSource(ID)` method over supported shell call IPC. Missing, scanning or mismatched inspection cannot authorize enable. Stale selection requires bounded rescan plus explicit matching inspection, not list rows or elapsed time. Both enable paths recheck this invariant; local provenance no longer attaches pristine canonical metadata to an ambiguous/stale selected source.
- **P1 case folding:** controlled Git commands force `core.ignorecase=false`; repository-local `core.ignorecase=true` remains harmless to extra-path detection. No user edits are reset, normalized away or deleted to pass verification.
- **P2 polling baseline:** action validation uses unconditional fresh `catalog verify`, sharing the existing bounded fetch/normalization path without reading/writing saved catalog data, validators, hash or refresh lock. Failed verification returns empty stale evidence, not cached authorization. Explicit browser refresh alone changes its persisted baseline; pending consent still deep-copies the exact ID/source/SHA.

First-party enable, disable/remove recovery, detached exact-SHA staging, no HEAD fallback, consent binding and unsigned/unsandboxed warnings remain. Neither the new inspection nor the application lock prevents arbitrary concurrent same-user filesystem changes.

### Consolidated check set

`scripts/check` was invoked once after integration. Static Qt6 analysis passed with **168 advisory host/dynamic-type warnings**, and **69 backend behavior/security assertions** passed. The new registry harness initially could not find mise-installed Node after PATH isolation; it now captures the absolute executable beforehand. The freshness success fixture initially used `git clone`, whose branch config the existing strict allowlist correctly refused; fixture preparation now mirrors controlled init/remote/exact-fetch/detached staging instead of weakening verification.

After these test-only corrections, the remaining consolidated checks were resumed without rerunning the already-passed backend/QML checks:

- **28 catalog freshness assertions** passed, covering refused A/server changed-SHA B, successful A/server metadata/new-listing B, independent fresh-evidence failures, byte-preserved browsing baseline, and explicit refresh/no-change coherence. ETag and validator-free raw-hash transitions both ran.
- **81 pinned-install assertions** passed, including actual-registry winning-shadow refusal, stale-selected-source refusal/refresh, matching singleton-array manifest IDs even when canonical A wins, duplicate/unrelated development symlinks, standalone and postpublication install-and-enable casefold/duplicate refusals, pristine success, first-party behavior and recovery.
- Actual Qt6 catalog model/source-provenance tests passed.
- Preview QML downloader boundary and decoder/cache/resource/format/concurrency suites passed.
- Real Omarchy standard add/validation/catalog, native lazy-build, installed-tree instruction exclusion, plain-install build/retry/dependency scenarios passed.
- Managed-install ownership, fingerprint mismatch, asynchronous discovery, JSONC round-trip, backup, unowned-target and symlink tests passed. The final whitespace check passed.

Permanent registry regressions execute the installed `PluginRegistry.qml` rescan script, `parseScanOutput`, `validateManifest`, `entryPointUrl` and `setEnabled` functions in a Node VM, plus the installed shell's actual list renderer. Git and platform validate/catalog/enable/disable/remove commands are real. HTTP/Git transport, shell IPC/config persistence and activation are simulated; selected entrypoint bytes are recorded, never executed. The duplicate harness no longer assumes activation reads `plugins/$id`. Node is a development test prerequisite, not an added runtime package.

### Actual rendered notification and consent surface

A temporary standalone Quickshell host rendered the current production `PluginBrowser.qml`, components and catalog model using installed `qs.Commons`/`qs.Ui` and the actual desktop/theme. A small host-only IPC adapter selected rows and invoked the production refresh, poll and consent/action methods; it did not replace their logic or freshness flags. Real catalog/action/local helpers used private cache/state and controlled authored catalog/transport fixtures. Engagement output alone was inert simulated data. The separate host kept the displayed A model observable across global platform rescans; it was not a model-only or Node UI simulation.

Visual inspection at **1120×748 logical size** and actual helper/result state observed:

1. Displayed reviewed A, then served different reviewed B. Polling showed **Refresh available**. Consent visibly retained A's full SHA and unsigned/unsandboxed warning. Accepting A was refused by fresh backend evidence; A remained displayed and a subsequent poll still showed the notification.
2. Explicit refresh displayed B and a no-change poll cleared the notification.
3. While A consent remained pending, explicit refresh loaded B into the model. The dialog still displayed A; accepting produced the visible changed-revision/new-consent-required refusal without installation.
4. With A displayed and B changing only metadata/new listings, consented install-and-enable succeeded for A. The visible completed-action message coexisted with **Refresh available**, and another poll retained it without replacing displayed A.
5. Explicit refresh loaded the unseen metadata/new listing, changed the detail description to B and returned the toolbar to **Refresh**. No-change polling kept the notification clear.

### Real shell activation and refusal

The managed desktop runtime was updated with recoverable backups and verified on disk and in the running shell as fingerprint `db72ef7ee494093fe2f15432117c2a6faa342c68b6d5389763202148df5c19b2`.

Only a locally authored inert panel (`local.oma-plug-sea-review-inert`) was activated. Reviewed A was `a2fc41efe64c974d5d112aa5a34232a942784bf4`; upstream B was `9cfb71fd9ef33fd4d990d9fab154302dceae0b01`. Catalog HTTP and Git network transport were substituted with that controlled repository; actual Git object operations, Omarchy validation, discovery/rescan, selected-source IPC inspection, activation, QML loading, disable and remove used the real platform.

The production action installed A detached and enabled it; the actually loaded panel's `revision` method returned **A**. After disable, a valid authored `zz-pluginsea-review-shadow` manifest shared the ID. The real registry inspection reported that shadow directory as winner; community enable returned `ok:false` with the ID disabled and no shadow activation. Removing the shadow and adding distinct untracked `extra.qml` under local `core.ignorecase=true` also refused enable, reported no clean authority, and retained both file spellings until explicit fixture removal. A separate native-Bash probe of the actual shared library independently observed A detached with `clean=false` and rejected `sea_verify` while both files remained present.

A transient unavailable shell response during rescan appeared as a JSON parse diagnostic in a successful disable result; later confirmed state remained disabled. No platform warning/exception was suppressed to achieve the proof. All target activation was authored inert code; the shadow and case-colliding content were never enabled.

### Delivery limits

Review statuses and README/architecture/platform/design contracts are updated. These are local remediation checks, not a fresh marketplace security baseline or approval. No installed Omarchy platform file was modified; no commit, push, label or marketplace submission was made. Temporary UI/transport/repository/screenshot scaffolding and the authored runtime fixture are removed; existing managed-install backups remain recoverable.

## Numeric manifest identity remediation — 2026-10-05

Remediated [Finding 4](immutable-install-review.md#finding-4--p2-numeric-comparison-conflates-distinct-registry-ids) only, preserving the uncommitted Findings 1–3 changes and their historical evidence. The established numeric false-refusal reproduction was not rerun before choosing the fix.

### Identity contract and native numerical evidence

Numeric manifest IDs become registry-equivalent strings before exact requested-string equality. Numeric `1000` matches `"1000"`, not `"1e3"`; numeric `1` is distinct from `"01"`. Nested singleton arrays use the same coercion. Raw discovery still includes development directory symlinks, excludes hidden staging and precedes deduplication. Installation collision authorization uses raw candidates, destination absence and shell rows, not the static catalog's narrower numeric-ID policy.

Native `/usr/bin/jq` is **1.8.2**, with decnum literal preservation. Its ordinary binary64 `tostring` differs from JavaScript: `1e-7` becomes `1e-07`, `1e-6` becomes `1e-06`, and `1e20` becomes `1e+20`. Moreover, simply forcing arithmetic is insufficient: literal `1.00000000000000011102230246251565404236316680908203126` rounds to `1` through jq's intermediate 17-digit conversion, while JavaScript selects `1.0000000000000002`. The helper retains the literal, corrects that potential double rounding using exact dyadic midpoints and ties-even, then normalizes shortest digits to JavaScript notation. Negative literals retain their original digits before magnitude conversion.

Source evidence: jq's [literal conversion](https://raw.githubusercontent.com/jqlang/jq/jq-1.8.2/src/jv.c) reduces to `DEC_NUMBER_DOUBLE_PRECISION=17`; [tonumber](https://raw.githubusercontent.com/jqlang/jq/jq-1.8.2/src/builtin.c) also creates preserved literals in decnum builds, so reparsing is not a fix. Its [dtoa implementation](https://raw.githubusercontent.com/jqlang/jq/jq-1.8.2/src/jv_dtoa.c) uses shortest nearest-roundtrip digits with even tie selection; the helper applies [ECMAScript Number string notation](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-tostring).

The implementation uses existing native jq binary64/dtoa and `frexp`/`ldexp`/`nextafter`, not Node or a new production package. The non-decnum direct-parser branch is implemented but was not exercised on another jq build; no cross-build compatibility proof is claimed. The tool shell's bare `jq` was jaq 2.3.0, not the native repository runtime, and was not used as the numerical oracle.

### Consolidated and focused checks

After integration and the authored live consumer exercise, `scripts/check` was invoked **once** and passed:

- **99 pinned-install assertions**, including both distinct numeric/string pairs present before disabled install and Install & enable, exact local provenance, standalone activation from actual registry-selected reviewed bytes, genuine duplicate install/enable refusal, singleton arrays, stale selection, development symlinks, case folding, exact SHA/consent, first-party behavior and recovery.
- **69 backend behavior/security assertions**, **28 catalog freshness assertions**, and actual Qt6 catalog-model/source-provenance scenarios.
- Preview QML/downloader and native decoder/cache/resource/format/concurrency suites.
- Real Omarchy standard self-install/validation/catalog, installed-tree instruction exclusion, native lazy-build/retry/dependency scenarios, managed ownership/fingerprint/asynchronous-discovery/JSONC/backup/symlink integration, and whitespace checks.
- Qt6 static analysis with **168 advisory host/dynamic-type warnings**.

That invocation initially passed 33 Node-VM numeric formatting cases. A subsequent native Qt probe showed seven out-of-range inputs were rejected by Qt's `JSON.parse`: underflow-to-zero and overflow spellings accepted by Node cannot establish actual platform registry behavior. Those fixtures were removed rather than pinning the Node-only behavior. `bash tests/numeric-format.sh` then passed the final **26** Qt-accepted cases, plus native Qt `JSON.parse`/`String` comparison through `tests/NumericIdentityTest.qml`; targeted native QML lint passed. Coverage includes notation thresholds, signed zero, large-integer binary64 rounding, nearest/tie boundaries, accepted subnormal and near-overflow values, and nested singleton numeric arrays.

The permanent harness executes installed registry scan/parse/validation/source-resolution/enable functions and the installed list renderer. Git and platform commands are real; HTTP/Git transport, shell IPC/config persistence and activation are simulated. It records actual selected entrypoint bytes without executing QML. The native Qt oracle independently prevents Node-only parsing assumptions from being treated as platform evidence. Node remains test-only.

### Real shell consumer proof

Only authored inert panels were activated. Catalog HTTP and Git network transport were routed to local authored repositories; actual Git objects, platform validation, discovery/rescan, running-registry selected-source inspection, enable/disable/remove and QML loading used the real desktop.

| Requested string ID | Unrelated numeric ID present before install | Reviewed A | Upstream B |
| --- | --- | --- | --- |
| `1e3` | `1000` | `918ae82be675686a3375afbe4a2a18fe271fe842` | `fb19b5ad72fe5109603806acdac8724abbe442b6` |
| `01` | `1` | `bc720df4aa9656d3be63592f6a091c042a13cc81` | `758065287e576edfb041cb41fecdbda591a1b97b` |

Both cases installed disabled at their canonical paths, exposed A as detached/clean provenance, and succeeded through standalone enable and Install & enable while the unrelated numeric manifest remained present. The real panel was explicitly summoned before loaded-method inspection; its `proof` returned **REVIEWED A 1e3** or **REVIEWED A 01**, never B. The first smoke attempt inspected before lazy panel loading and stopped; summoning the authored panel corrected the proof procedure, not production code.

For string `1000`, an existing numeric `1000` refused install and Install & enable without publication. After unique pristine A (`f268e5ed29736d0f458e18e197f503c5de585c32`) was installed disabled, a valid later numeric shadow became the observed registry winner. Local provenance was suppressed, standalone enable was refused, and A's checkout remained clean and disabled; the shadow remained disabled. Recovery removal succeeded.

The unchanged platform enable command emitted its static catalog `startswith() requires string inputs` diagnostic with numeric manifests present, but actual enable and confirmed state succeeded. Transient rescan/list parsing diagnostics also remained visible in recovery output. No warning/exception was hidden or platform manifest policy changed to obtain the proof. The live smoke removed its authored fixtures and byte-compared restored `shell.json` with the original.

### Actual rendered consumer surface and current runtime

After the consolidated run, a temporary standalone Quickshell host rendered the current production browser/components/model on the real desktop at **1120×748 logical size**. A host-only IPC adapter opened and selected the authored `1e3` detail and invoked production consent/cancel methods; it did not synthesize local provenance or enable eligibility. Real helpers used private cache/state, authored catalog/Git transport and the real running registry's selected-source inspection. The fixture's generic transport supplied no valid engagement payload, so its rejection warning remained visibly displayed.

With numeric `1000` present, disabled `1e3` showed an enabled **Enable** control. Actual correlated local state contained A's full SHA, canonical path, `detached:true` and `clean:true`; `enableAvailable` was true. The rendered consent named exact ID/repository/A, reported observed detached/clean snapshot/content match and different upstream, and retained unsigned/unsandboxed warnings. Consent was cancelled, not accepted.

The managed runtime was installed with recoverable backups and verified on disk and in the running browser as fingerprint `1b3f383fe49a6c1514c3d78c396626642c35cbaf171ebae6bb322af8d782a6fa`. These are local remediation checks, not a new slow-model review, signed security baseline or marketplace approval. No installed Omarchy platform file or arbitrary third-party code was modified/activated; no project commit, push or submission was made.

Final cleanup stopped the standalone proof process, removed the disabled rendered fixture through the production recovery helper, and removed the authored shadow. The real local helper returned `ok:true` with **41 plugins** and no fixture IDs; all fixture paths were absent, `shell.json` remained byte-identical to its pre-smoke copy, and the current managed runtime fingerprint still verified. Temporary repositories, transport wrappers, native Qt probes, UI host/private cache/state and screenshots were removed. Existing managed-install recovery backups remain.

## Numeric discovery cost remediation — 2026-10-05

Remediated [Finding 5](immutable-install-review.md#finding-5--p2-repeated-numeric-conversion-blocks-local-inspection-and-actions) without replacing Findings 1–4 or unrelated working-tree changes. The documented 150-second local timeout and 120030-ms action failure were treated as established evidence, not rerun.

### Implemented cost boundary

`bin/oma-plug-sea-local` excludes first-party rows and checks canonical manifest existence plus path/manifest/Git symlink eligibility before discovery. It lazily creates one raw-candidate NDJSON snapshot in its private temporary observation directory, reused only by eligible metadata rows. `sea_unique_candidates(ID,PATH)` filters exact canonical IDs before uniqueness. Each selected-source inspection and the original post-inspection path checks remain; Git metadata is observed afterwards.

The snapshot is not persisted or reused between invocations, and is not backend activation authority. `sea_unique_source` still performs fresh raw discovery on every call. Action-level fresh source, selected-source and content verification remain unchanged, including both community enable paths. No timeout was raised, error hidden, candidate omitted, valid numeric manifest rejected or Node runtime dependency added.

Exact dyadic midpoint construction now multiplies decimal strings in blocks of 20 powers, then a remainder. `5^20=95367431640625` and `2^20=1048576` are exact factors. For decimal digit `d<=9` and carry `c<=F-1`, `d*F+c<=953674316406249<2^50<2^53`; products/sums are exactly representable. Quotients after division by 10 are below `2^47`, with maximum rounding error `1/128`, less than the minimum nonintegral distance `0.1` from an integer. Thus floor/borrow/carry propagation remains exact, including multi-digit carry and initial `-1` borrowing. An exponent magnitude of 1,075 uses 53 block passes plus 15 remainder passes instead of 1,075 individual passes. Binary64 midpoint comparisons, ties-even, power-of-two spacing, signs and JavaScript notation remain unchanged.

### Bounded ordinary-row timing and successful consumers

A throwaway isolated HOME/cache/state contained exactly one unrelated authored manifest, with literal `5.0000000000000000001e-324` preserved verbatim. Native Qt `JSON.parse`/`String` accepted it as **`5e-324`**. The installed registry functions and actual shell list renderer produced **39 rows**, retaining all ordinary bundled first-party manifests.

Timing used monotonic Node `performance.now()` around synchronous invocations of the actual production helper/action, with a **20-second subprocess bound** per invocation. Node was only the throwaway measurement driver and existing registry VM; no concurrent bulk stress or consolidated workload ran during measurement. This was a controlled scenario, not a permanent timing threshold or general performance guarantee.

| Actual invocation / state | Elapsed | Observed result |
| --- | ---: | --- |
| Local helper, one numeric manifest / 39 rows | **43 ms** | `ok:true`, numeric identity retained |
| Disabled install with that manifest already present | **1930 ms** | Reviewed A published detached and disabled |
| Local helper with canonical reviewed A / 40 rows | **562 ms** | Exact A, canonical path, detached/clean provenance |
| New observation after a real duplicate was added | **423 ms** | Canonical provenance suppressed |
| Enable with that new duplicate | **834 ms** | Refused, no selected bytes activated |
| New observation after duplicate removal | **602 ms** | Unique pristine A provenance restored |
| Standalone enable with numeric manifest present | **4060 ms** | Enabled; exact reviewed A bytes selected |
| Dirty-content recovery disable | **1242 ms** | Disabled; authored edit retained |
| Dirty-content recovery remove | **799 ms** | Target removed; numeric source retained |
| Local helper after recovery / 39 rows | **48 ms** | Ordinary observation still succeeds |
| First-party disable / enable | **289 / 321 ms** | Both confirmed successful beside numeric source |
| Install & enable with numeric manifest present | **3959 ms** | Exact A enabled, detached/clean |
| Final disable / remove | **1260 / 922 ms** | Successful; numeric manifest unchanged |

The reviewed source was `https://github.com/test/numeric-cost`, ID `review.numeric-cost`, reviewed A **`8547b9db15bc0c2fdc58d27eaa2117eea55dfefa`**, with distinct upstream B **`2ae606a3f26a268deb88d2ca38b7b1bf14cd29ee`**. Both enable choices recorded A's actual registry-selected entrypoint bytes, never B. A later losing duplicate was detected even though the selected registry source remained canonical A, proving no prior observation's uniqueness authorized enable. The unrelated numeric manifest remained byte-identical throughout recovery and first-party operations.

Real work: production local/action/discovery/Git-provenance helpers, Git objects/fetch/checkout/status, installed platform validation/list/enable/disable/remove dispatch, installed registry scan/parse/validation/source-resolution/setEnabled and list-rendering functions, and native Qt number parsing. Simulated work: HTTP/Git network transport, shell IPC/config persistence and activation through the existing isolated registry harness. Entrypoint bytes were recorded, not executed; no live third-party QML was activated in this timing scenario.

The unchanged platform enable command emitted its static catalog `startswith() requires string inputs` diagnostic with the valid numeric manifest present. Successful confirmed state and the diagnostic were both retained; nothing was suppressed.

### Consolidated check set

`scripts/check` was invoked **once after integration**, after the bounded timing exercise had completed. All checks passed:

- **29 numeric identity cases** against installed registry functions and native Qt `JSON.parse`/`String`: the original 26 plus the slow scalar, its negative and nested singleton-array variant. Genuine numeric/string collisions and wrong expected source remain rejected.
- **114 pinned-install assertions**: the original 99 plus successful long-subnormal coexistence, exact A/canonical provenance, added/removed duplicate observations, standalone and combined enable, dirty-content recovery, first-party operations and byte-preserved numeric manifest.
- **28 catalog freshness assertions**, **69 backend behavior/security assertions**, and actual Qt6 model/source-provenance scenarios.
- Preview boundary/decoder/cache/resource/format/concurrency checks, real standard add/validation/catalog and native lazy-build/retry/dependency scenarios, installed-tree instruction exclusion, and managed ownership/fingerprint/asynchronous-discovery/JSONC/backup/symlink integration.
- Qt6 static analysis with **168 advisory host/dynamic-type warnings** and final whitespace checks.

No permanent timing threshold, microbenchmark or wiring/call-count test was added. The numeric helper predicate is exercised through real raw manifests and existing consumers; Node remains test-only. Qt's existing C-locale-to-UTF-8 diagnostic was retained and did not affect the native numeric oracle.

### Current real shell and rendered local state

After the consolidated checks, the managed runtime was deployed with recoverable backups and verified on disk and in the running shell as fingerprint **`27c453b5df4c7fa43e9c32c71fa996a6aed9a0bf143e676e4f0548543a8bd68d`**. The initial live probe inherited its private fixture `umask 077` into deployment, causing copied asset/manifest modes to produce a mismatched fingerprint; the existing verifier refused it. Redeploying with standard `umask 022` corrected that smoke procedure without modifying integration code or weakening fingerprint checks.

An authored inert numeric manifest with the same verbatim long literal was temporarily added to the real user plugin directory. The **installed** current local helper, using actual running-shell IPC and discovery rather than harness transport/state, completed in **568 ms**, returning `ok:true` with **42 rows**, numeric ID `5e-324`, `enabled:false` and `active:false`.

Actual keyboard interaction searched for `5e-324` and opened its detail in the current production browser at **1120×748 logical size**. Visual inspection showed **Inert numeric cost probe**, ID **5e-324**, its local-only state and a disabled Enable control; the browser reported one matching row, `detail:"5e-324"` and `localError:""`. No standalone UI host, synthesized local rows or arbitrary community activation was used. The live numeric fixture was never enabled.

The browser was hidden and the owned numeric directory removed. Final real local inspection returned `ok:true` with **41 rows** and no numeric fixture; the original `shell.json` bytes were preserved and the current runtime fingerprint still verified. Transient JSON parse diagnostics during the removal rescan remained visible; the final observed state converged successfully without hiding them.

No installed Omarchy platform file was modified, no arbitrary third-party code was activated, and no project commit, push or marketplace submission was made. Managed recovery backups remain; this is local Finding 5 remediation evidence, not a new slow-model review or marketplace approval.

Temporary timing drivers, transport/IPC wrappers, isolated HOME/cache/state, authored Git repositories, native Qt probe records, live fixture files and screenshots were removed. The authored browser search/detail interaction was cleared; the current managed runtime and pre-existing recovery backups remain.

