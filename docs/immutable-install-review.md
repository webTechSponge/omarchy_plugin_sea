# Immutable installation: post-commit review

Date: 2026-10-04.
Reviewed commit: `9c9ea8217fd02ef46f50c8f20bcf88622a019cae` — Bind plugin installation and enable to verified immutable snapshots.
Review model: OMP `@slow`, resolved to `openai-codex/gpt-6-astra:high`.
Status: **Findings 1–4 remain closed by slow-model review of the working-tree remediation. Finding 5 is remediated with bounded numerical conversion, observation-local reuse, successful timed consumers and consolidated checks. No new slow-model re-review is claimed. Not pushed, submitted or marketplace-approved.** Initial post-fix evidence is recorded in [verification](verification.md#immutable-install-review-remediation--2026-10-04), Finding 4 evidence is [appended separately](verification.md#numeric-manifest-identity-remediation--2026-10-05), and Finding 5 evidence is [recorded here](verification.md#numeric-discovery-cost-remediation--2026-10-05); historical reproductions below remain unchanged.

The slow-model reviewers examined the install/Git path and catalog/UI contracts separately. The parent assistant reproduced all three findings using isolated fixtures. No tracked implementation files were changed during review. Temporary reproduction harnesses were removed.

The original [immutable-install plan](immutable-install-plan.md) remains the intended contract. Its initial implementation and runtime evidence do not cover the failures below. The two P1 findings bypass the new reviewed-snapshot enable boundary; the P2 finding breaks catalog change notification.

## Finding 1 — P1: verification and activation can select different directories

Primary location at the reviewed commit: `bin/oma-plug-sea-action:121–128`, especially the duplicate-ID check at line 122.
Related implementation: `verify_community()` checks `$HOME/.config/omarchy/plugins/$id`; `enable_plugin()` invokes Omarchy by ID. `bin/oma-plug-sea-local` also observes the canonical `$id` directory rather than the registry-selected source.

**Finding status: remediated and locally verified.** Raw manifest discovery rejects matching IDs before deduplication, including development links and registry-coerced singleton-array identities. Both community enable paths require the running registry's selected source to match the verified canonical checkout through the loaded browser's non-executing `activationSource` IPC bridge. Stale selection is rescanned and explicitly inspected; unavailable/scanning inspection fails closed. Local provenance is withheld for ambiguous or stale-selected sources. Actual-registry regressions cover standalone/install-and-enable refusal, stale winners, unrelated symlinks, first-party enable and recovery; real-shell authored-fixture smoke confirmed the shadow winner and refused activation.

### Cause and consequence

The action counts matching IDs in the shell's already-deduplicated list. That list cannot reveal two discovered directories with the same manifest ID. The backend can therefore verify pristine reviewed A in `plugins/test.pinned` while the shell selects another directory, `plugins/zz-shadow`, for that ID.

Installed platform evidence inspected during review:

- `/usr/share/omarchy/shell/services/PluginRegistry.qml:685–687`: scans third-party directories in glob order.
- `PluginRegistry.qml:563–569`: records `manifest.__sourceDir` and overwrites `thirdParty[validated.id]` for later manifests with the same ID.
- `PluginRegistry.qml:599–611`: publishes the winning manifests in `installedPlugins`.
- `PluginRegistry.qml:456`: `setEnabled()` selects the manifest from `installedPlugins` by ID.
- `PluginRegistry.qml:93–107`: resolves an entrypoint relative to that manifest's `__sourceDir`.
- `/usr/share/omarchy/shell/shell.qml:952–978`: emits one list row per registry ID, without the selected source path.
- `/usr/share/omarchy/bin/omarchy-plugin-enable:85`: dispatches enable by ID through shell IPC.
- `/usr/share/omarchy/bin/omarchy-plugin-catalog:61`: also applies `unique_by(.id)`. Counting this catalog's rows is not a substitute for checking raw discovery candidates.

This requires no concurrent filesystem modification. The same-user filesystem-race exclusion does not cover a static duplicate that already exists before verification.

### Reproduction and observed evidence

1. Use isolated HOME/cache/state and the existing real-Git pinned-install fixture. Install reviewed A disabled at `plugins/test.pinned`.
2. Add `plugins/zz-shadow/manifest.json` with the same plugin ID and a distinct inert `Fixture.qml` containing `UNREVIEWED SHADOW`.
3. Execute the installed registry's actual `rescan`, `parseScanOutput`, manifest validation, and `entryPointUrl` functions against these directories. The reproduction ran these functions in a Node VM, supplying plain-object/file-URL utilities and inert signal/process scaffolding.
4. Request standalone enable for A using the real action helper. Preserve real Git, platform catalog, and platform validation. Simulate shell activation using the source selected in step 3, rather than assuming activation reads `plugins/$id`.

Observed:

```text
registry winner: plugins/zz-shadow
registryRows: 1
entrypoint: plugins/zz-shadow/Fixture.qml
action result: ok=true, clean=true, enabled=true
enabled source content: UNREVIEWED SHADOW
```

Limit: the live desktop was not enabled or used to execute the shadow fixture. Registry source selection was exercised with the actual functions; shell IPC/state and activation were simulated. The backend's false authorization was observed, not inferred.

### Required remediation and acceptance

- Bind the community verification decision to the source the shell will activate. Reject ambiguous discovered IDs before activation; do not rely on either deduplicated shell rows or static catalog rows to establish uniqueness.
- Apply the invariant to standalone enable and install-and-enable. Preserve installation collision checks and unrelated development-symlink support.
- Keep first-party enable and recovery disable/remove available under their existing safety restrictions.
- Add an isolated behavior regression: pristine canonical A plus a valid duplicate with the same ID must refuse enable, and no shadow entrypoint may be activated. The harness must model actual registry source selection rather than hardcode `plugins/$id` at the activation boundary.
- Demonstrate that a unique pristine reviewed installation still enables and that an unrelated development symlink does not cause refusal.
- Do not claim protection against arbitrary concurrent same-user filesystem mutation.

## Finding 2 — P1: Git case folding hides additional unreviewed content

Primary location at the reviewed commit: `lib/git-provenance.sh:46`.
Related implementation: `sea_git():2–10`, `sea_observe()`'s Git status enumeration and literal-byte comparison.

**Finding status: remediated and locally verified.** The shared controlled Git invocation forces `core.ignorecase=false`, independent of allowed repository-local case folding. Real-Git regressions report the tracked `Extra.qml`/distinct untracked `extra.qml` checkout non-clean and refuse both enable paths without deleting or repairing contents. The live authored fixture was refused, and a native-Bash shared-library probe independently observed detached reviewed HEAD with `clean=false` while both files remained present.

### Cause and consequence

The local-config allowlist permits `core.ignorecase=true`, but the controlled Git invocation does not override it. On a case-sensitive filesystem, an additional untracked path can be hidden from Git's enumeration if its spelling differs only in case from an indexed path. Reporting ignored files does not prevent this suppression.

The subsequent literal-byte loop checks only paths present in the committed tree. Consequently both checks can miss the extra path, and `sea_verify()` can authorize a checkout containing unreviewed content. A reviewed entrypoint that dynamically loads the lowercase filename could consume that content; execution of such a loader was not part of the reproduction.

### Reproduction and observed evidence

1. Create an isolated real-Git checkout with tracked `manifest.json` and `Extra.qml`; commit it, detach at the full SHA, and set a supported canonical HTTPS origin.
2. Confirm `sea_verify()` accepts the pristine checkout.
3. Set repository-local `core.ignorecase=true` and add different untracked content at `extra.qml`.
4. Invoke the actual shared library's `sea_observe()` and `sea_verify()`.
5. Compare with the same Git status invocation using `-c core.ignorecase=false`.

Observed:

```text
extra.qml exists: true
sea_clean with case folding: true
sea_verify accepted untracked extra.qml: true
case-sensitive Git status: ?? extra.qml
```

Limit: this reproduction exercised real Git and the actual verification library, not live plugin execution.

### Required remediation and acceptance

- Make extra-path detection independent of repository-local case folding. Explicit case-sensitive Git enumeration is the minimal candidate fix; independently enumerating filesystem paths is another option if needed.
- Do not reset or delete user modifications to make verification pass.
- Add a regression on a case-sensitive filesystem with tracked `Extra.qml`, different untracked `extra.qml`, and `core.ignorecase=true`. Observation must not report a clean match, and community enable must be refused without activating additional content.
- Cover standalone enable and install-and-enable's shared verification behavior. Retain successful verification/enable for a pristine reviewed checkout and existing tracked/untracked/ignored tampering coverage.

## Finding 3 — P2: action refresh advances an unseen catalog's polling baseline

Primary location at the reviewed commit: `bin/oma-plug-sea-action:78`.
Related implementation: `bin/oma-plug-sea-catalog` persists shared HTTP validators/content hashes; `PluginBrowser.qml:391–395` reconciles action results only into local plugin state; `PluginBrowser.qml:348–349` replaces `refreshNeeded` from polling results.

**Finding status: remediated and locally verified.** Actions use fresh, nonpersisting catalog `verify`; only explicit browsing `refresh` replaces the saved model's validators/hash baseline. Isolated regressions cover refused and successful actions with ETag and raw-hash polling, failed fresh evidence, and explicit baseline reconciliation. The actual rendered browser retained **Refresh available** after refusal and successful install-and-enable, cleared it only after explicit refresh/no-change polling, preserved pending A consent when the displayed model became B, and refused changed-consent dispatch.

### Cause and consequence

An action-time catalog refresh replaces the shared cache and its change-detection baseline. The browser does not replace its displayed catalog after the action. Polling then compares the server against the action-refreshed cache, rather than against the catalog the user has actually loaded.

This occurs even when the action refuses because the listing SHA changed. The next poll can clear a previously detected update while the old listing remains visible. New listings, revocations, and changed snapshot details can remain undisclosed until a manual refresh. Backend snapshot checks still refuse stale consent; this finding is a browsing/freshness regression, not an observed snapshot-install bypass.

### Reproduction and observed evidence

1. Refresh catalog A and retain the resulting displayed model with listing SHA `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`.
2. Serve catalog B with changed validators and listing SHA `bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb`.
3. Poll before acting; observe that a refresh is needed.
4. Request installation using A's consented SHA. The fresh-evidence check refuses installation but caches B.
5. Poll again without explicitly refreshing the displayed model.

The isolated reproduction invoked the actual catalog/action helpers, with mocked HTTP transport and empty platform list/catalog responses:

```text
displayedRevision: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
refreshNeededBeforeAction: true
actionOk: false
actionError: The selected reviewed snapshot is not currently eligible in a fresh catalog. Refresh and review again.
cachedRevisionAfterAction: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
refreshNeededAfterAction: false
```

The unchanged displayed-model behavior was established from the QML action completion handler. This reproduction did not render the live browser.

### Required remediation and acceptance

- Keep action validation from silently advancing the displayed model's polling baseline, or explicitly reconcile/invalidate that baseline after actions.
- Preserve fresh backend authorization and consent binding to ID, repository, and SHA. Do not silently substitute a new revision while a consent dialog is pending.
- Add behavior coverage for displayed A/server B followed by an action using A. A refused action must not erase the notification for unseen B; successful actions that refresh evidence must also leave displayed-model freshness coherent.
- After an explicit successful refresh to B, the displayed model and polling baseline must agree, and a no-change poll may clear the notification.
- Verify the actual browser surface for notification behavior and changed-consent refusal; backend helper output alone does not prove the UI fix.

## Finding 4 — P2: numeric comparison conflates distinct registry IDs

Review date: 2026-10-04. Scope: working-tree remediation against base commit `9c9ea8217fd02ef46f50c8f20bcf88622a019cae`, including the new `lib/plugin-discovery.sh`.
Review model: OMP `@slow`, resolved to `openai-codex/gpt-6-astra:high`.
**Finding status: closed by slow-model re-review of the working-tree identity fix on 2026-10-05.** The separate numeric-discovery performance regression found during that review is tracked as Finding 5 below.

Primary location at re-review: `lib/plugin-discovery.sh:25–27`, in `sea_candidates_for_id()`.
Consumers: `sea_unique_source()`, `bin/oma-plug-sea-local`, and community installation/enable guards in `bin/oma-plug-sea-action`.

### Cause and consequence

The matching predicate converts the requested string ID to a number when comparing numeric manifest IDs:

```jq
select(.id==$id or
  ((.id|type)=="number" and (.id == (try ($id|tonumber) catch null))))
```

This differs from the registry's JavaScript `String(id)` representation. A reviewed plugin with string ID `"1e3"` and an unrelated manifest with numeric ID `1000` have distinct registry keys, `"1e3"` and `"1000"`. The helper nevertheless counts both as candidates for `"1e3"`. The same numeric-equivalence problem applies to requested string `"01"` versus numeric manifest ID `1`.

Consequently an unrelated plugin can cause installation collision refusal or make an already installed, pristine reviewed checkout lose local provenance and fail community enable. This is a false refusal, not an observed activation-source security bypass. Both original P1 security findings and the original P2 catalog-freshness finding remain closed.

### Reproduction and observed evidence

1. Use the existing pinned-install fixture in isolated HOME/cache/state, with the target plugin's string ID changed to `"1e3"`. Install reviewed A disabled at `plugins/1e3`; this succeeds before the second manifest exists.
2. Add an otherwise valid unrelated manifest under `plugins/numeric` with numeric ID `1000` and an authored inert entrypoint.
3. Rescan through the installed registry functions using `tests/registry-selection.cjs`, and render the list using the installed shell's actual list renderer.
4. Invoke the actual `sea_candidates_for_id()` and `sea_unique_source()` helpers for string ID `"1e3"`.
5. Request standalone enable for `"1e3"` with its consented repository and reviewed SHA using the real action helper.

Observed:

```text
Actual registry identities: ["1000", "1e3"]
Candidates for "1e3":
  {"id":"1e3","sourceDir":".../plugins/1e3"}
  {"id":1000,"sourceDir":".../plugins/numeric"}
sea_unique_source: false
Standalone enable: ok=false
Reviewed plugin metadata: headCommit="", clean=false, enabled=false
```

The action returned: `Enable refused: source, detached reviewed revision, clean contents or fresh listing do not match. Inspect or manage externally.`

Limit: Git, action/local/discovery helpers, platform commands and installed registry/list functions were real. HTTP/Git transport, shell IPC/config persistence and activation were simulated by the existing isolated harness. No live third-party plugin was activated. The temporary reproduction harness and fixture were removed; tracked implementation files were not edited.

### Required remediation and acceptance

- Match numeric manifest identities using the registry's JavaScript string representation, not numeric equivalence to the requested ID. Choose a solution within existing runtime dependencies; Node is a test prerequisite, not a production dependency.
- Preserve genuine duplicate detection. A numeric manifest ID `1000` must still collide with string ID `"1000"`; it must not collide with string ID `"1e3"`. Likewise numeric `1` must not collide with string `"01"`.
- Preserve existing registry-coerced singleton-array duplicate detection, selected-source inspection, stale-winner refusal/rescan, and unrelated development-symlink support. Do not fix false refusals by ignoring numeric manifests entirely.
- Add deterministic isolated regressions that exercise actual registry identities and consumer behavior. Distinct IDs must preserve reviewed local provenance and permit pristine community enable; a distinct numeric manifest already present must not block installation. Genuine matching IDs must continue to refuse installation/enable without activating an unreviewed source.
- Check numeric spelling/formatting against the registry behavior rather than assuming a jq conversion is equivalent. Keep the scope to identity matching and its affected callers/tests/docs; do not change the platform's manifest policy or unrelated validation.
- Leave both case-folding protection and nonpersisting catalog verification intact. Do not reset/delete user content or weaken exact-SHA/consent checks.

### Verification exercised during re-review

- `bash tests/pinned-install.sh`: passed 81 assertions.
- `bash tests/catalog-freshness.sh`: passed 28 assertions.
- `bash tests/backend.sh`: passed 69 assertions.
- `bash tests/model.sh`: passed Qt 6 catalog-model/source-provenance scenarios.
- The read-only live local helper returned `ok:true` with 41 plugins. The running browser's source-inspection bridge returned its canonical selected source and returned empty, unsuccessful inspection for a nonexistent plugin.
- The isolated numeric-ID scenario above reproduced this remaining failure despite those passing suites.

These are re-review results, not post-fix proof for Finding 4. The slow-model reviewers assessed all three original findings as closed; the parent assistant confirmed the new P2 through the isolated reproduction. No full consolidated check or new live-desktop activation/UI proof was performed during this re-review.

### Post-fix remediation and exercised evidence — 2026-10-05

`lib/plugin-discovery.sh` converts numeric manifest IDs to JavaScript Number string identities before exact string matching; the requested ID is never converted to a number. Native jq shortest digits need JavaScript notation normalization, and jq 1.8.2 decnum input additionally needs correction of intermediate 17-digit rounding against exact binary64 midpoints. Recursive singleton-array identity coercion remains. Installation collision checks now use authoritative raw candidates and shell rows without the redundant static catalog call, whose `startswith` rejects numeric IDs accepted by the registry.

Observed after remediation:

- Numeric `1000` already present before installing string `"1e3"`, and numeric `1` before string `"01"`, permitted disabled exact-SHA installation, canonical detached/clean provenance, standalone enable and Install & enable. The real loaded authored panels returned reviewed A, not upstream B.
- Genuine numeric/string `1000` duplicates refused both installation choices. A subsequently winning numeric shadow suppressed canonical provenance and refused standalone enable; the reviewed checkout remained pristine and disabled.
- The single consolidated `scripts/check` invocation passed 99 pinned-install, 69 backend and 28 freshness assertions, Qt models, preview, real standard-install and managed-integration suites; Qt analysis reported 168 advisory warnings.
- A native Qt probe found seven initial formatting inputs were rejected by Qt JSON parsing despite acceptance by the Node VM. Those invalid platform fixtures were removed, not repinned. The corrected focused regression passed **26** cases through installed registry functions, helper uniqueness/collision checks and a new native Qt `JSON.parse`/`String` oracle; its QML lint also passed.
- The production browser rendered an enabled Enable control and exact reviewed-SHA consent for disabled `"1e3"` while numeric `1000` was present. Consent visibly reported detached/clean snapshot/content match and retained unsigned/unsandboxed warnings; it was cancelled without activation.

Simulation limits, native jq assumptions, real-shell snapshots, runtime fingerprint and cleanup are recorded in [Finding 4 verification evidence](verification.md#numeric-manifest-identity-remediation--2026-10-05). Findings 1–3, platform manifest policy and historical reproductions remain unchanged; Node remains test-only.


## Finding 5 — P2: repeated numeric conversion blocks local inspection and actions

Review date: 2026-10-05. Scope: working-tree remediation of Finding 4 against base commit `9c9ea8217fd02ef46f50c8f20bcf88622a019cae`.
Review model: OMP `@slow`, resolved to `openai-codex/gpt-6-astra:high`.
**Finding status: remediated; post-fix evidence appended below. Not marketplace-approved.**

Primary changed-code location: `lib/plugin-discovery.sh:49–55`, where numeric conversion constructs exact upper/lower binary64 midpoints.
Amplifying consumer: `bin/oma-plug-sea-local:13–22`, which invokes `sea_unique_source()` before checking for a canonical third-party manifest.
Action deadline: `bin/oma-plug-sea-action:54–57` gives each local inspection 120 seconds.
Browser consumer: `PluginBrowser.qml` runs the local helper directly, without an equivalent process deadline.

### Cause and consequence

The identity conversion is correct, but some accepted long numeric literals take an expensive midpoint path. For numeric ID `5.0000000000000000001e-324`, each of the two midpoint calculations performs roughly 1,075 decimal multiplication passes.

The local helper iterates the installed shell rows and runs full raw manifest discovery for each eligible ID. It repeats conversion of every numeric candidate before checking whether that row even has a canonical third-party manifest. Ordinary first-party rows therefore amplify the cost despite having no local metadata to attach.

One unrelated, valid numeric manifest can stall browser local-state refresh and make actions fail before dispatch. The shared initial local inspection also gates enable, disable and removal; the action timeout was exercised with installation, not separately with every recovery verb. This is an availability/performance regression, not an identity mismatch or observed unreviewed activation.

### Reproduction and observed evidence

Use isolated HOME/cache/state with one authored inert manifest at `plugins/numeric/manifest.json`:

```json
{"schemaVersion":1,"id":5.0000000000000000001e-324,"name":"Inert numeric fixture","version":"1.0.0","kinds":["panel"],"entryPoints":{"panel":"Fixture.qml"}}
```

The entrypoint contains only an inert QtQuick `Item`; it is never activated.

1. Confirm the manifest through `tests/NumericIdentityTest.qml`. Native Qt accepts the literal and produces identity `"5e-324"`.
2. Use `tests/registry-selection.cjs` to execute the installed registry discovery/validation and shell list renderer, preserving the ordinary bundled first-party manifests. Route fixture shell IPC to that isolated registry state.
3. Invoke the actual `bin/oma-plug-sea-local` against that state. The focused reproduction did not complete within a 150-second subprocess deadline.
4. With no concurrent bulk stress workload, invoke the actual action helper:

```sh
bin/oma-plug-sea-action install review.numeric-cost \
  https://github.com/test/numeric-cost \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --consent-unsandboxed
```

Observed action-level evidence:

```text
Native Qt JSON.parse/String: accepted; identity "5e-324"
Registry/list rows: 39
Numeric ID present: true
Action elapsed: 120030 ms
Action result: {"ok":false,"error":"Cannot inspect plugin state; ensure omarchy-shell is running."}
```

The registry/list operation succeeded; the action failed because the repeated local inspection exceeded its own 120-second deadline. No catalog/Git installation dispatch, publication or plugin activation occurred.

Limits: the actual local/action helpers, native jq/Qt, installed registry functions/list renderer and platform list dispatch were exercised. Shell IPC/config persistence were simulated through the existing isolated harness. The separate direct-local 150-second run overlapped a synthetic bulk probe; the action-level 120-second failure was then reproduced after that bulk probe was cancelled, removing that contention. The synthetic bulk run is not correctness proof. No live third-party plugin was activated, no tracked implementation file was edited, and temporary probes/fixtures were removed.

The slow reviewer reassessed this as a confirmed P2 with 0.99 confidence after receiving the parent assistant's action-level evidence. Findings 1–4 remain closed.

### Required remediation and acceptance

- Avoid full discovery/conversion for shell rows that cannot receive canonical third-party metadata. Check eligibility before paying numeric conversion cost; do not weaken source/manifest/symlink safety checks.
- Compute reusable raw-candidate identities once per local-state observation instead of once per row. Keep raw discovery before deduplication, and do not introduce a persistent authority cache that can authorize stale filesystem contents.
- Keep the expensive conversion path bounded enough for ordinary local refresh and action inspection to complete promptly. If conversion itself needs optimization, preserve registry-equivalent numeric identities and binary64 rounding correctness; Node remains test-only.
- Do not raise deadlines, suppress the failure, omit valid candidates, or reject valid numeric manifests as a workaround.
- Exercise the focused one-manifest/ordinary-row scenario after remediation. Record actual local-helper and action elapsed times; the action must no longer fail its local-inspection deadline. Use controlled fresh evidence and authored fixtures to exercise a successful consumer path, not just a different eventual refusal.
- Demonstrate disable/remove recovery and first-party behavior remain available with the valid numeric manifest present. Do not activate arbitrary third-party code.
- Preserve exact numeric/string identity distinctions, genuine numeric/string duplicates, registry-coerced singleton arrays, selected-source binding/stale-winner checks, unrelated development symlinks, case-folding protection, nonpersisting catalog verification, exact-SHA installation and consent binding.
- Keep deterministic consumer behavior regressions where practical. Use a bounded throwaway timing smoke rather than a flaky permanent microbenchmark or tests that only assert wiring/call counts.

### Verification exercised during this review

- `bash tests/numeric-format.sh`: passed 26 identity cases against installed registry functions and native Qt `JSON.parse`/`String`, including genuine collisions.
- `bash tests/pinned-install.sh`: passed 99 assertions.
- `bash tests/catalog-freshness.sh`: passed 28 assertions.
- `bash tests/backend.sh`: passed 69 assertions.
- `bash tests/model.sh`: passed Qt 6 catalog-model/source-provenance scenarios.
- `scripts/verify-runtime` verified the current installed/running runtime fingerprint, `1b3f383fe49a6c1514c3d78c396626642c35cbaf171ebae6bb322af8d782a6fa`; the live source-inspection bridge returned the canonical browser source.
- The focused local/action timeout reproductions above exposed Finding 5 despite those passing checks.

These are pre-fix review results for Finding 5. No post-fix proof, new full consolidated check or live third-party activation was performed during this review.

### Post-fix remediation and exercised evidence — 2026-10-05

Local observation now skips first-party and missing/symlink-ineligible canonical manifests before discovery, then shares one lazily built raw-identity snapshot among eligible rows in its private temporary directory. The snapshot is removed on exit and is metadata-only. Backend source/content checks still rediscover and verify afresh immediately before activation.

Exact midpoint decimal arithmetic uses 20-exponent power blocks plus remainders, with multi-digit carry handling and exact integer/floor bounds. For the subnormal's 1,075-exponent construction, 53 block passes plus 15 remainder passes replace 1,075 individual passes without changing JavaScript identity or binary64 rounding.

Observed post-fix:

- With the verbatim accepted literal and **39 actual registry/list rows**, the production local helper returned `ok:true` in **43 ms**. Successful controlled disabled installation took **1930 ms**, installing exact reviewed A rather than upstream B.
- With canonical A present, local inspection took **562 ms** and retained exact detached/clean provenance. Standalone enable and Install & enable succeeded and recorded actual selected A bytes; dirty-content disable/remove and first-party enable/disable succeeded with the numeric manifest retained.
- New observations detected a newly added losing duplicate, suppressed provenance and refused enable; removing it restored unique provenance. No earlier observation authorized the later action.
- `scripts/check` ran once after integration and passed **29** native Qt/installed-registry numeric cases, **114** pinned-install assertions, **28** freshness assertions, **69** backend assertions, model, preview, standard-install and managed-integration suites. Qt analysis reported **168** advisory warnings.

Full timings, precision bounds, simulation limits and final runtime/cleanup evidence are [appended in verification](verification.md#numeric-discovery-cost-remediation--2026-10-05). The documented failure was not rerun. No timeout, manifest policy, activation safeguard or production dependency was weakened; Findings 1–4 and historical results remain intact.


## Verification already exercised during review

- `bash tests/pinned-install.sh`: passed 60 assertions, using real Git/platform validator/catalog with transport and shell state simulated.
- `bash tests/model.sh`: passed Qt 6 catalog-model/source-provenance scenarios.
- `bash tests/backend.sh`: passed 64 backend behavior/security assertions.
- Three temporary isolated reproductions confirmed the findings above and were removed.

Those checks and reproductions were performed during the original review, before remediation. They did not include implementation fixes, post-fix proof, consolidated checks or live-desktop reproduction. Subsequent remediation and observed verification are appended in [verification](verification.md#immutable-install-review-remediation--2026-10-04), rather than rewriting these historical results.

## Implementation handoff constraints

The current implementation handoff is **Finding 5 only**. Preserve the remediation of Findings 1–4; do not reopen or replace it while correcting repeated numeric-discovery cost. Reuse existing helpers and test conventions. Preserve exact-SHA installation, no mutable-HEAD fallback, first-party enable, recovery actions, unsigned-catalog/unsandboxed warnings, and the documented same-user race limit. Do not modify installed Omarchy platform files.

Keep deterministic, isolated behavior regressions for the newly exposed failures. Exercise each changed path after remediation; run the consolidated existing checks once after integration, then verify the actual changed UI and an authored inert plugin scenario where authorized. Report what was simulated and what ran against the real platform. Update this document's finding status and append exercised evidence to `docs/verification.md`; do not rewrite historical review results as post-fix proof. Do not commit, push, or submit to the marketplace unless separately requested.
