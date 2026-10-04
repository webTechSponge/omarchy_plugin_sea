# Immutable installation and marketplace resubmission plan

## Decision and scope

Keep in-app installation, including Install & enable, but install only the exact marketplace-verified listing snapshot. Remove in-app updates to mutable upstream HEAD. Continue using Omarchy for static validation, discovery, enable, disable, and removal.

Implementation and local runtime proof are complete; see [verification evidence](verification.md#immutable-snapshot-installation--2026-10-04). This document retains the agreed design and resubmission checklist. No installed Omarchy scripts were modified, no package dependency was added, and no push or marketplace submission was made.

The marketplace submission [#5215](https://github.com/omacom/omarchy-plugin-marketplace/issues/5215) was closed on September 22, 2026. Its [September 14 review](https://github.com/omacom/omarchy-plugin-marketplace/issues/5215#issuecomment-5672438941) requires a full reviewed commit SHA, detached checkout of that object, verification before enable, and either reviewed immutable updates or external manual updates.

## Observed constraints

- `bin/oma-plug-sea-action` currently hands installation to `omarchy plugin add` and updates to `omarchy plugin update`. Neither installed CLI interface accepts an exact SHA.
- `lib/normalize.jq` already preserves `listingValidatedCommit`, `verificationSnapshotStatus`, `verificationCoverage`, and `verificationStatus`. The action protocol does not receive a revision.
- `PluginBrowser.qml` already copies the selected detail into `pendingPlugin` before consent. Extend that existing snapshot; do not introduce a second consent state machine.
- The installed add implementation clones, validates, moves the checkout into the plugin directory, and rescans. Pinned installation must replace its clone/publication portion, not call add and reset afterward.
- Both the installed CLI catalog and Quickshell registry exclude hidden staging entries. The shell watcher also ignores paths whose first relative component begins with a dot. A private hidden staging directory inside the plugin directory permits same-filesystem atomic publication without discovery of the staged checkout.
- Shell configuration can contain dormant references that activate newly discovered code. Preserve the existing stale-reference guard and recheck immediately before publication.
- The marketplace's [verification policy](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md) distinguishes verified listing snapshots from newer unverified upstream commits. Gate on the snapshot evidence, not just the effective upstream status.
- HTTPS catalog metadata remains unsigned. Pinning binds downloaded Git content to the selected catalog revision; it does not authenticate marketplace signing authority, sandbox code, or establish safety.

## 1. Define one installation eligibility contract

Files: `lib/normalize.jq`, `js/CatalogModel.js`, `fixtures/catalog.json`.

- Keep the raw catalog's availability restrictions, supported root-repository layout, canonical HTTPS GitHub source, reserved namespace restriction, and lifecycle blocks.
- Require `listingValidatedCommit` to be a full 40-character hexadecimal SHA.
- Require the deployed machine value `verificationSnapshotStatus: "verified"` and a matching full lowercase `verificationCommit` equal to `listingValidatedCommit`. Unknown, absent, malformed, mismatched or unverified values fail closed.
- A newer observed upstream commit does not invalidate installation of the older verified listing snapshot. Never select `upstreamObservedCommit`, a branch, tag, short SHA, or HEAD as a fallback.
- Bind eligibility to the selected plugin ID, repository, and listing SHA. Reject unsupported multi-plugin layouts rather than guessing a manifest path.
- Normalize unavailable entries with a specific explanation. The UI and backend must enforce the same rule; hiding a button is not enforcement.
- Reject stale/unavailable catalog evidence for a new install. Browse and cached display remain usable offline.

Acceptance: a listing with a verified old snapshot and a different upstream HEAD offers the old snapshot; missing or unverified snapshot evidence offers no in-app install.

## 2. Replace mutable installation with staged exact checkout

Primary file: `bin/oma-plug-sea-action`.

New install protocol:

`install|install-enable ID REPOSITORY FULL_SHA --consent-unsandboxed`

- Preserve bounded commands, JSON result envelopes, argument arrays, canonical-source checks, serialized mutations, shell.json backups, and explicit unsandboxed consent.
- Refresh/revalidate the catalog through the existing helper before installation. Require the current entry to match the consented ID, repository, and SHA and still satisfy eligibility. A changed listing requires new consent; do not silently substitute a revision.
- Validate ownership and reject symlinked state/plugin directory components before writing. Lock acquisition must not follow an attacker-supplied symlink.
- Create a private hidden staging container inside `~/.config/omarchy/plugins`; place the checkout inside it. Keep it excluded from both discovery paths throughout preparation.
- Use a controlled Git configuration and empty template/hook setup for initialization, fetch, and checkout. Do not execute repository hooks, recurse into submodules, or inherit executable checkout filters. Preserve source/transport restrictions throughout the operation.
- Fetch the exact requested object from the canonical HTTPS GitHub repository. Checkout detached. If the server cannot provide that SHA, fail; do not fetch/install HEAD instead.
- Verify the object is a commit, HEAD equals the consented SHA, the checkout is detached and clean, origin matches, and the root manifest ID is exactly the requested ID.
- Run the actual `omarchy plugin validate` against the staged root without running community code. Retain platform rejection of unsafe file layouts.
- Immediately before promotion, recheck catalog identity, installed-ID collisions, destination absence, and dormant configuration references.
- Publish through a same-filesystem atomic rename with no overwrite and no copy fallback. A concurrent destination creation must fail rather than nest into or replace that directory. Keep the canonical origin for provenance and explicit external management.
- Request shell rescan, confirm discovery and disabled state, and verify the published checkout again. Install & enable proceeds only through the enable checks in section 3.
- Pre-publication failures clean only the private staging directory. Post-publication failures report the actual state and retain the installation for inspection/removal; never claim a rollback occurred or remove unrelated/preexisting content.

Acceptance: if repository HEAD is B and the consented reviewed snapshot is A, only A reaches the discoverable directory. No content from B is enabled or imported during the operation.

## 3. Verify revision and checkout content before enable

Files: `bin/oma-plug-sea-local`, `bin/oma-plug-sea-action`, `js/CatalogModel.js`.

- Expose observed local Git revision, detached/clean state, and supported origin as provenance metadata using the existing local-state envelope.
- Add the same pre-enable verification to Install & enable and the standalone Enable action. Passing only the initial install check leaves a bypass after external modifications.
- For community code enabled through this app, bind consent to the eligible catalog snapshot and require matching repository, manifest ID, detached HEAD, and clean checkout immediately before invoking Omarchy enable.
- Detect modified tracked files and additional untracked/ignored content that could change executed code; HEAD equality alone is insufficient. Keep generated preview caches outside the checkout as they are now.
- Do not reset or delete user edits to make enable pass. Refuse with an explanation and leave disable/remove available.
- Preserve first-party platform enable behavior. Local-only, unknown-origin, unmatched, or manually modified community installs cannot be enabled through this reviewed-snapshot path; users may manage them explicitly outside the app.
- No installation receipt is treated as verification authority. An older installed commit no longer matching the current eligible listing cannot be re-enabled through the app without restoring/installing the current eligible snapshot or external management.
- Describe matching provenance as a snapshot/content match, never as a security certification.

Acceptance: changing HEAD, origin, manifest ID, a tracked entry point, or adding executable content after disabled installation prevents in-app enable.

Boundary: the app serializes its own actions, not arbitrary processes running as the same user. Immediate checks narrow external races but do not defend against a hostile same-user process modifying files during enable.

## 4. Cut over UI and remove mutable update execution

Files: `PluginBrowser.qml`, `components/PluginDetails.qml`, `js/CatalogModel.js`, `bin/oma-plug-sea-action`.

- Extend the existing consent snapshot with the exact target SHA. Show the repository, immutable revision, install-disabled versus enable behavior, and unsandboxed warning.
- Pass that SHA in the action arguments. Revalidate eligibility after consent; failures must require the user to refresh/review rather than silently changing the target.
- Replace “Check & update” with explicit external-update guidance. Remove the update action implementation, argument construction, consent branch, result checks, and obsolete comments. Direct attempts to invoke the obsolete action fail without fetching or mutating code.
- Explain that external Omarchy updates follow mutable upstream HEAD, are outside this app's reviewed-snapshot guarantee, and may cause live reload if a plugin is enabled. Advise disabling before an external update and inspecting the resulting code/revision before external enable.
- Update availability, lifecycle, verification, detail, and diagnostics wording to reflect exact-snapshot installation. Keep browsing, source inspection, previews, hearts, disable, and removal unchanged.

Acceptance: no UI interaction can trigger a mutable update; both install choices name the exact revision that the backend installs.

## 5. Regression coverage and runtime proof

Files: existing backend/model tests and fixtures; a focused real-Git pinned-install regression alongside the existing standard-install tests.

Keep `tests/standard-cli-install.sh` as coverage of installing Plugin Sea itself through Omarchy. That separate path still exists; do not rewrite it to pretend the platform installer supports pinning.

Update broken action/eligibility contracts and remove tests that merely preserve obsolete wording, argv echoes, or mutable-update implementation details. Add behavior coverage for:

1. Reviewed A versus different upstream B: installed files and HEAD are A, detached and initially disabled.
2. Verified snapshot with unverified newer upstream: select A, never B.
3. Missing/invalid SHA, unverified snapshot, revoked/unavailable listing, or consent/catalog mismatch: no published installation.
4. Exact-object fetch failure or invalid/mismatched manifest: no discoverable staging contents, no fallback to HEAD, no enable.
5. Dormant configuration references, symlinked paths, unsafe Git configuration, duplicate IDs, and destination collisions: refusal without overwriting existing content.
6. Tampering between install and standalone enable: altered revision, origin, tracked content, or extra executable files prevent enable.
7. Publication/rescan/enable failure: accurate final-state reporting; unrelated files/configuration survive.
8. Obsolete direct update request: no code/network mutation.

Use actual Git repositories and the real platform validator for the A/B scenario. Keep HOME, Git config, cache/state, and fixtures isolated. Where shell IPC is simulated, report that limit; test enable refusal through observable state and execution sentinels, not mocked forwarding assertions.

After implementation, run the consolidated existing checks once, then smoke the actual changed UI in a managed development installation. Exercise consent SHA display, unavailable-install explanation, external-update guidance, and successful exact-snapshot installation using an authorized fixture. Never enable arbitrary community code to obtain smoke evidence. Remove throwaway smoke scaffolding afterward.

## 6. Documentation and new submission

After runtime proof:

- Update `README.md`, `docs/architecture.md`, and `docs/platform-research.md` with the new install contract, enable restrictions, external-update workflow, and remaining trust/race limits.
- Append observed verification evidence to `docs/verification.md`; preserve dated historical evidence rather than rewriting it as current behavior.
- Keep dependency documentation accurate: this design uses existing Bash/Git/jq/coreutils/Omarchy tools and adds no package dependency.
- Finalize one commit, record its full SHA, and keep default-branch HEAD unchanged throughout marketplace review.
- Open a new marketplace submission referencing #5215 and the exact security-review comment. Explain staged pinned installation, pre-enable verification, and removal of in-app mutable updates.
- Request fresh validation and security baseline for that commit. Ensure validation SHA, decoded baseline SHA, and default-branch HEAD match before requesting maintainer review.
- Request the current publication path (`approved-and-verified`) only after the maintainer accepts the exact evidence. A label or a closed issue alone is not proof of publication.

## Completion criteria

- Every in-app community install selects and installs a currently eligible immutable listing snapshot, with no mutable-HEAD fallback.
- Both enable paths verify the selected revision and installed content before enabling.
- In-app mutable updates and all their callers are removed.
- Tests and actual UI/runtime evidence cover the changed boundary; docs describe the implementation rather than the former CLI handoff.
- The resubmission identifies one frozen, freshly validated commit and the original review blocker.

## Planning checks observed on October 4, 2026

- Installed `omarchy plugin --help`: add/update have no exact-revision option; validate/enable/disable/remove are available.
- `omarchy plugin validate .`: exited successfully.
- `omarchy plugin list --json`: valid discovery output with 41 plugins, 34 enabled.
- Inspected installed add, catalog, enable, and shell-registry implementations for publication and hidden-staging behavior.
- The planning stage changed only this document. Subsequent implementation, regressions and real-shell exact-snapshot smoke are recorded in [verification evidence](verification.md#immutable-snapshot-installation--2026-10-04).
