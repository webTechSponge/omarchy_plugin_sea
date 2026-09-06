# Security hardening plan — findings 2–5

Source: security + integrity review (2026-09-06). Finding 1 (origin-check TOCTOU
vs. external Git config) is inherent to the upstream CLI and already documented
in `bin/oma-plug-sea-action` and consent text; no code change planned here.

## Fix 2 — installed-source link must be GitHub-canonical or disabled

Target: `js/CatalogModel.js:49-57`, `components/PluginDetails.qml:15,61-62`.

- Add `function safeGitHubLink(url) { return canonicalGitHub(url) !== ""; }`
  beside `safeLink`. Leave `safeLink` untouched: `PluginBrowser.qml:28`
  (preview gate) needs the marketplace host, not GitHub.
- `PluginDetails.qml:15`: `installedSourceLink:
  Catalog.canonicalGitHub(Catalog.sourceUrl(plugin)) || ""` (drop the raw
  fallback; SSH spellings already canonicalize to https).
- Line 61: gate on `Catalog.safeGitHubLink(detail.installedSourceLink)`;
  line 62 (catalog button): gate on `safeGitHubLink(detail.plugin.repo)`.
  Normalized repos are GitHub-or-empty, so line 62 behavior is unchanged
  except a foreign host can never pass.
- Edge: non-GitHub installed origin renders the button disabled; the existing
  `provenanceNote` ("unknown or unsupported") already explains why.
- Tests: extend `tests/ModelTest.qml` — `safeGitHubLink("https://evil.example/phish")
  == false`, `safeGitHubLink("git@github.com:o/r") == true`; correlate a local
  row with a foreign `repo` and assert the canonical link resolves to `""`.
- Verify: `bash tests/model.sh`, `scripts/qml-check`.

## Fix 3 — local helper must not follow symlinked manifest (and .git)

Target: `bin/oma-plug-sea-local:10-20`.

- After `path=...`, insert before the manifest read:
  `[[ ! -L $path/manifest.json && ! -L $path/.git ]] || continue`.
  Closes file-symlink reads through `jq` and `.git`-symlink origin spoofing;
  the existing `! -L $path` parent check stays.
- Edge: real files/dirs pass; a symlinked entry contributes no metadata row,
  identical to a missing manifest today.
- Tests: extend `tests/backend.sh` isolated-HOME section — symlink
  `$HOME/.config/omarchy/plugins/<id>/manifest.json` at a decoy JSON file plus
  a list entry, assert the helper omits that id's metadata; repeat for a
  symlinked `.git`.
- Verify: `bash tests/backend.sh`.

## Fix 4 — owned-dir guards for catalog + preview caches

Target: `bin/oma-plug-sea-catalog:69-71`, `bin/oma-plug-sea-preview:10-12`,
mirroring `bin/oma-plug-sea-build-preview:33-42`.

- Add the builder's guard inline in each script (6 lines, existing style, no new
  shared lib): absolute-path check, `! -L` check, `mkdir -p`, `-d` + `-O`
  ownership check, `chmod 700`.
- Catalog failure mode: stale `fallback` envelope (never hard-exit, preserves
  last-good). Preview failure mode: `reply false '' 'Preview cache
  unavailable.'`. The preview lock file inherits the guarded directory.
- Edge: relative/empty `XDG_CACHE_HOME` rejected before `mkdir`; existing
  user-owned dirs pass; root-owned or symlinked dirs refuse with an actionable
  error.
- Tests: `tests/backend.sh` — point `XDG_CACHE_HOME` at a tree containing
  `oma_plug_sea -> /tmp/evil`, assert refresh returns `stale:true` and writes
  nothing outside; `tests/preview.sh` — same shape for the previews dir,
  assert `ok==false`.
- Verify: `bash tests/backend.sh`, `bash tests/preview.sh`.

## Fix 5 — sanitize validators on the refresh write path

Target: `bin/oma-plug-sea-catalog:84-85`, reusing the check-path predicate
(`:24-25`).

- Shell-side: `etag=$(header_value etag "$headers" | tr -d '\r\n')`, same for
  `modified`; then `[[ $etag =~ ^[[:print:]]{1,512}$ ]] || etag=""` before
  `jq --arg`. `header_value` is line-oriented (trailing `\r` stripped, `\n`
  impossible), `jq --arg` encoding already prevents JSON breakage, and only the
  already-sanitized check-path copy is re-emitted as `-H` — `tr -d` is
  belt-and-braces.
- Edge: a hostile `ETag: x\r\nInjected: y` arrives as two `-D` lines;
  `header_value` keeps the last match only; the stored value stays CRLF-free.
- Tests: `tests/backend.sh` mock-curl section — emit a CRLF-bearing `ETag`,
  assert stored `.sourceValidators.etag` contains no `\r`/`\n` and the next
  `check` sends a single `If-None-Match` line (existing `conditions`-log
  assertion pattern).
- Verify: `bash tests/backend.sh`.

## Order + final verification

1. Fix 3 → 4 → 5 (helpers, independent files) → Fix 2 (QML/JS).
2. `bash -n bin/*`, `mise run check` (backend + Qt model + preview +
   integration suites), `git diff --check`.
3. No README/architecture change: behavior matches the documented contracts.
   Record applied results in `docs/verification.md`.
