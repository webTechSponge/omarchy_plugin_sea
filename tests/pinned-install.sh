#!/usr/bin/env bash
# Real Git, installed validation/catalog, registry discovery/validation/source
# resolution and shell list renderer. Transport, IPC and activation are simulated.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
platform=${OMARCHY_PATH:-/usr/share/omarchy}
real_git=$(command -v git)
real_node=$(command -v node)
export REAL_GIT="$real_git"
registry_harness="$root/tests/registry-selection.cjs"
[[ -x $platform/bin/omarchy-plugin-validate && -x $platform/bin/omarchy-plugin-catalog ]] || { echo 'Installed Omarchy validator/catalog required' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/source" "$tmp/template" "$tmp/home/.config/omarchy/plugins"
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TEMPLATE_DIR="$tmp/template" LC_ALL=C
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
export PATH="$tmp/bin:$platform/bin:/usr/bin:/bin" OMARCHY_PATH="$platform"
export GIT_AUTHOR_DATE='2026-10-04T00:00:00Z' GIT_COMMITTER_DATE='2026-10-04T00:00:00Z'
# Prefix paths into the wrapper: the backend intentionally clears environment.
printf '#!/usr/bin/env bash\nset -euo pipefail\nfixture=%q\nreal=%q\n' "$tmp" "$real_git" > "$tmp/bin/git"
cat >> "$tmp/bin/git" <<'WRAPPER'
args=("$@")
for ((i=0;i<${#args[@]};i++)); do
  [[ ${args[i]} == fetch ]] || continue
  printf 'fetch\n' >> "$fixture/fetches"
  [[ ! -e $fixture/fetch-fail ]] || exit 71
  # Only the transport destination changes. Exact refspec and all object,
  # checkout, config, status and revision operations are real Git.
  for ((j=i+1;j<${#args[@]};j++)); do
    if [[ ${args[j]} == origin ]]; then args[j]="$fixture/source"; break; fi
  done
  ((j<${#args[@]})) || exit 97
  prefix=("${args[@]:0:i}")
  "$real" "${prefix[@]}" -c protocol.file.allow=always "${args[@]:i}"
  if [[ -e $fixture/change-catalog ]]; then cp "$fixture/catalog-next.json" "$fixture/catalog.json"; fi
  if [[ -e $fixture/race-destination ]]; then
    mkdir -p "$fixture/home/.config/omarchy/plugins/test.pinned"
    printf 'existing content\n' > "$fixture/home/.config/omarchy/plugins/test.pinned/retain"
  fi
  if [[ -e $fixture/race-config ]]; then printf '{"plugins":[{"id":"test.pinned"}]}' > "$fixture/home/.config/omarchy/shell.json"; fi
  exit 0
done
exec "$real" "$@"
WRAPPER
printf '#!/usr/bin/env bash\nset -euo pipefail\nfixture=%q\n' "$tmp" > "$tmp/bin/curl"
cat >> "$tmp/bin/curl" <<'WRAPPER'
[[ ! -e $fixture/network-fail ]] || exit 7
while (( $# )); do
  case $1 in
    -o) cp "$fixture/catalog.json" "$2"; shift ;;
    -D) printf 'HTTP/2 200\r\n\r\n' > "$2"; shift ;;
    -w) printf 200; shift ;;
  esac
  shift
done
WRAPPER
printf '#!/usr/bin/env bash\nset -euo pipefail\nfixture=%q\nplatform=%q\nharness=%q\nnode=%q\n' "$tmp" "$platform" "$registry_harness" "$real_node" > "$tmp/bin/omarchy-shell"
cat >> "$tmp/bin/omarchy-shell" <<'WRAPPER'
[[ $1 == shell ]] || exit 98
case $2 in
 ping) echo ok ;;
 rescanPlugins) [[ ! -e $fixture/rescan-fail ]]; "$node" "$harness" "$fixture" "$platform" rescan ;;
 listPlugins) "$node" "$harness" "$fixture" "$platform" list ;;
 call) [[ $3 == webtechsponge.plugin-sea && $4 == activationSource ]]; "$node" "$harness" "$fixture" "$platform" source "$5" ;;
 enablePlugin) [[ ! -e $fixture/enable-fail ]]; "$node" "$harness" "$fixture" "$platform" enable "$3" ;;
 setPluginEnabled) [[ $4 == false ]]; "$node" "$harness" "$fixture" "$platform" disable "$3" ;;
 *) exit 98 ;;
esac
WRAPPER
# Dispatch real platform enable/disable as well as validate/catalog/list.
printf '#!/usr/bin/env bash\nset -euo pipefail\nplatform=%q\nexec \"$platform/bin/omarchy\" \"$@\"\n' "$platform" > "$tmp/bin/omarchy"
chmod +x "$tmp/bin/"*
printf '[]' > "$tmp/enabled.json"
printf '{"retained":"configuration"}' > "$HOME/.config/omarchy/shell.json"
cat > "$tmp/source/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"test.pinned","name":"Inert reviewed fixture","version":"1.0.0","kinds":["panel"],"entryPoints":{"panel":"Fixture.qml"}}
JSON
printf 'import QtQuick\nItem { property string revision: "A" }\n' > "$tmp/source/Fixture.qml"
printf '*.ignored\n' > "$tmp/source/.gitignore"
printf 'import QtQuick\nItem { property string reviewed: "extra A" }\n' > "$tmp/source/Extra.qml"
"$real_git" init -q "$tmp/source"
"$real_git" -C "$tmp/source" add .
"$real_git" -C "$tmp/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm A
A=$("$real_git" -C "$tmp/source" rev-parse HEAD)
printf 'import QtQuick\nItem { property string revision: "B" }\n' > "$tmp/source/Fixture.qml"
"$real_git" -C "$tmp/source" add .
"$real_git" -C "$tmp/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm B
B=$("$real_git" -C "$tmp/source" rev-parse HEAD)
repo=https://github.com/test/pinned
jq -n --arg a "$A" --arg b "$B" --arg repo "$repo" '{plugins:[{id:"test.pinned",name:"Inert reviewed fixture",repo:$repo,installAvailable:true,upstreamAvailable:true,status:"active",repositoryLayout:"root-plugin",manifestPath:"manifest.json",verificationSnapshotStatus:"verified",verificationCommit:$a,listingValidatedCommit:$a,upstreamObservedCommit:$b,verificationCoverage:"update-unverified"}]}' > "$tmp/catalog-good.json"
cp "$tmp/catalog-good.json" "$tmp/catalog.json"
act="$root/bin/oma-plug-sea-action"
installed="$HOME/.config/omarchy/plugins/test.pinned"
pass=0
assert() { jq -e "$1" "$tmp/result" >/dev/null || { echo "FAIL: $2" >&2; cat "$tmp/result" >&2; exit 1; }; pass=$((pass+1)); }
run() { "$act" "$@" > "$tmp/result"; }
install() { run install test.pinned "$repo" "$A" --consent-unsandboxed; }
refused() { assert '.ok==false' "$1"; [[ ! -e $installed && ! -L $installed ]]; [[ ! -s $tmp/enabled-content ]]; [[ -z $(find "$HOME/.config/omarchy/plugins" -mindepth 1 -maxdepth 1 -print -quit) ]]; }
reset_case() {
  rm -rf -- "$installed"
  rm -f "$tmp/"{fetch-fail,network-fail,change-catalog,race-destination,race-config,rescan-fail,enable-fail,enabled-content,registry.json,inject-shadow,inject-casefold}
  cp "$tmp/catalog-good.json" "$tmp/catalog.json"
  printf '[]' > "$tmp/enabled.json"
  printf '{"retained":"configuration"}' > "$HOME/.config/omarchy/shell.json"
}
install
assert '.ok and any(.plugins[];.id=="test.pinned" and (.enabled|not))' 'Reviewed A installs disabled'
[[ $("$real_git" -C "$installed" rev-parse HEAD) == "$A" ]]
! "$real_git" -C "$installed" symbolic-ref -q HEAD
cmp "$installed/Fixture.qml" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
[[ $("$real_git" -C "$installed" remote get-url origin) == "$repo" ]]
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert 'any(.plugins[];.id=="test.pinned" and .detached and .clean and (.headCommit|length)==40)' 'Observed provenance is exposed'
# Executable inherited config must neither run nor redirect the controlled Git.
"$real_git" config --file "$tmp/unsafe-global" core.fsmonitor "touch $tmp/executed-config"
"$real_git" config --file "$tmp/unsafe-global" url."file://$tmp/not-the-source/".insteadOf https://github.com/
reset_case
GIT_CONFIG_GLOBAL="$tmp/unsafe-global" install
assert '.ok' 'Inherited Git executable config and URL rewrites are isolated'
[[ ! -e $tmp/executed-config && $("$real_git" -C "$installed" rev-parse HEAD) == "$A" ]]
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok and any(.plugins[];.id=="test.pinned" and .enabled)' 'Pristine standalone enable confirms observed state'
cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
# Static duplicate: the actual installed registry chooses zz-shadow, not A.
reset_case; install; assert '.ok' 'Prepare duplicate-source enable'
mkdir -p "$HOME/.config/omarchy/plugins/zz-shadow"
cp "$tmp/source/manifest.json" "$HOME/.config/omarchy/plugins/zz-shadow/manifest.json"
printf 'UNREVIEWED SHADOW\n' > "$HOME/.config/omarchy/plugins/zz-shadow/Fixture.qml"
omarchy-shell shell rescanPlugins
"$real_node" "$registry_harness" "$tmp" "$platform" source test.pinned > "$tmp/source-result"
jq -e --arg path "$HOME/.config/omarchy/plugins/zz-shadow" '.sourceDir==$path' "$tmp/source-result" >/dev/null
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert 'any(.plugins[];.id=="test.pinned" and (.clean|not) and .headCommit=="" and .localPath=="")' 'Ambiguous discovery never exposes canonical pristine provenance'
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Winning zz-shadow duplicate refuses standalone enable'
[[ ! -s $tmp/enabled-content && -d $installed/.git ]]
# A non-string ID accepted by actual registry String(id) must also count before
# deduplication, even when it sorts BEFORE canonical A and loses source selection.
mkdir -p "$HOME/.config/omarchy/plugins/aa-array-shadow"
jq '.id=[["test.pinned"]]' "$tmp/source/manifest.json" > "$HOME/.config/omarchy/plugins/aa-array-shadow/manifest.json"
printf 'UNREVIEWED ARRAY-ID SHADOW\n' > "$HOME/.config/omarchy/plugins/aa-array-shadow/Fixture.qml"
rm -rf "$HOME/.config/omarchy/plugins/zz-shadow"
omarchy-shell shell rescanPlugins
"$real_node" "$registry_harness" "$tmp" "$platform" source test.pinned > "$tmp/source-result"
jq -e --arg path "$installed" '.sourceDir==$path' "$tmp/source-result" >/dev/null
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Registry-valid nested singleton-array duplicate refuses even when canonical reviewed A wins'
[[ ! -s $tmp/enabled-content ]]
rm -rf "$HOME/.config/omarchy/plugins/aa-array-shadow"
# Restore the stale winning-shadow fixture used below.
mkdir -p "$HOME/.config/omarchy/plugins/zz-shadow"
cp "$tmp/source/manifest.json" "$HOME/.config/omarchy/plugins/zz-shadow/manifest.json"
printf 'UNREVIEWED SHADOW\n' > "$HOME/.config/omarchy/plugins/zz-shadow/Fixture.qml"
omarchy-shell shell rescanPlugins
# Remove duplicate without refreshing: list ID is unchanged, selected source is not.
rm -rf "$HOME/.config/omarchy/plugins/zz-shadow"
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert 'any(.plugins[];.id=="test.pinned" and (.clean|not) and .headCommit=="")' 'Stale shadow registry never receives canonical pristine provenance'
touch "$tmp/rescan-fail"
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Stale selected source with failed rescan never activates'
[[ ! -s $tmp/enabled-content ]]
rm "$tmp/rescan-fail"
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok and any(.plugins[];.id=="test.pinned" and .enabled)' 'Stale shadow selection is rescanned to unique reviewed A before enable'
cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
reset_case; install; assert '.ok' 'Prepare duplicate-symlink enable'
mkdir -p "$tmp/shadow-development"
cp "$tmp/source/manifest.json" "$tmp/shadow-development/manifest.json"
printf 'UNREVIEWED SYMLINK SHADOW\n' > "$tmp/shadow-development/Fixture.qml"
ln -s "$tmp/shadow-development" "$HOME/.config/omarchy/plugins/zz-shadow"
omarchy-shell shell rescanPlugins
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Discoverable duplicate development symlink refuses enable'
[[ ! -s $tmp/enabled-content && -L $HOME/.config/omarchy/plugins/zz-shadow ]]
rm "$HOME/.config/omarchy/plugins/zz-shadow"
reset_case; install; assert '.ok' 'Prepare casefold standalone enable'
"$real_git" -C "$installed" config core.ignorecase true
printf 'UNREVIEWED CASEFOLD\n' > "$installed/extra.qml"
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert 'any(.plugins[];.id=="test.pinned" and (.clean|not))' 'Observation sees distinct extra.qml despite core.ignorecase=true'
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Casefold-hidden extra content refuses standalone enable'
[[ ! -s $tmp/enabled-content && $(cat "$installed/extra.qml") == 'UNREVIEWED CASEFOLD' ]]
for injection in shadow casefold; do
  reset_case
  touch "$tmp/inject-$injection"
  run install-enable test.pinned "$repo" "$A" --consent-unsandboxed
  assert '.ok==false' "Postpublication $injection refuses install-enable"
  [[ -d $installed/.git && ! -s $tmp/enabled-content ]]
  if [[ $injection == shadow ]]; then
    [[ $(cat "$HOME/.config/omarchy/plugins/zz-shadow/Fixture.qml") == 'UNREVIEWED SHADOW' ]]
    rm -rf "$HOME/.config/omarchy/plugins/zz-shadow"
  else
    [[ $(cat "$installed/extra.qml") == 'UNREVIEWED CASEFOLD' ]]
  fi
done
# Mutations cannot be repaired/reset silently to permit enable.
for mutation in tracked untracked ignored head branch origin manifest symlink gitlink config index writable; do
  reset_case; install; assert '.ok' 'Prepare disabled checkout'
  case $mutation in
    tracked) printf '\n// user edit\n' >> "$installed/Fixture.qml" ;;
    untracked) printf 'extra code\n' > "$installed/Untracked.qml" ;;
    ignored) printf 'extra code\n' > "$installed/Extra.ignored" ;;
    head) "$real_git" -C "$installed" -c protocol.file.allow=always fetch "$tmp/source" "$B" >/dev/null 2>&1; "$real_git" -C "$installed" checkout --detach "$B" >/dev/null 2>&1 ;;
    branch) "$real_git" -C "$installed" checkout -b edited >/dev/null 2>&1 ;;
    origin) "$real_git" -C "$installed" remote set-url origin https://github.com/other/pinned ;;
    manifest) jq '.id="test.wrong"' "$installed/manifest.json" > "$tmp/manifest"; cp "$tmp/manifest" "$installed/manifest.json" ;;
    symlink) mv "$installed/manifest.json" "$tmp/manifest"; ln -s "$tmp/manifest" "$installed/manifest.json" ;;
    gitlink) mv "$installed/.git" "$tmp/linked-git"; ln -s "$tmp/linked-git" "$installed/.git" ;;
    config) "$real_git" -C "$installed" config core.fsmonitor "touch $tmp/executed-config" ;;
    index) "$real_git" -C "$installed" update-index --assume-unchanged Fixture.qml; printf '\n// hidden edit\n' >> "$installed/Fixture.qml" ;;
    writable) chmod 666 "$installed/Fixture.qml" ;;
  esac
  run enable test.pinned "$repo" "$A" --consent-unsandboxed
  assert '.ok==false' "Enable refuses $mutation"
  [[ ! -s $tmp/enabled-content && -d $installed ]]
  [[ ! -e $tmp/executed-config ]]
  rm -rf "$tmp/linked-git"
done
reset_case
run install-enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok and any(.plugins[];.id=="test.pinned" and .enabled)' 'Install-enable confirms simulated shell state'
cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
for change in missing short unverified revoked unavailable source sha; do
  reset_case
  case $change in
    missing) filter='del(.plugins[0].listingValidatedCommit)' ;;
    short) filter='.plugins[0].listingValidatedCommit="abc123"' ;;
    unverified) filter='.plugins[0].verificationSnapshotStatus="unverified"' ;;
    revoked) filter='.plugins[0].status="yanked"' ;;
    unavailable) filter='.plugins[0].installAvailable=false' ;;
    source) filter='.plugins[0].repo="https://github.com/other/pinned"' ;;
    sha) filter='.plugins[0].listingValidatedCommit=.plugins[0].upstreamObservedCommit | .plugins[0].verificationCommit=.plugins[0].upstreamObservedCommit' ;;
  esac
  jq "$filter" "$tmp/catalog-good.json" > "$tmp/catalog.json"
  install; refused "Ineligible or changed consent: $change"
done
reset_case
run install test.pinned "$repo" "$A"
refused 'Missing explicit consent'
reset_case
run install test.pinned "$repo" --consent-unsandboxed
refused 'No SHA fallback'
reset_case; touch "$tmp/fetch-fail"; install; refused 'Exact-object fetch failure has no HEAD fallback'
reset_case
absent=ffffffffffffffffffffffffffffffffffffffff
jq --arg sha "$absent" '.plugins[0].listingValidatedCommit=$sha | .plugins[0].verificationCommit=$sha' "$tmp/catalog-good.json" > "$tmp/catalog.json"
run install test.pinned "$repo" "$absent" --consent-unsandboxed
refused 'Real Git cannot fetch absent object and never falls back to HEAD'
reset_case; touch "$tmp/network-fail"; install; refused 'Stale cached catalog cannot authorize install'
reset_case; rm -f "$XDG_CACHE_HOME/oma_plug_sea/catalog.json"; touch "$tmp/network-fail"
install; refused 'Fresh catalog failure without cache cannot install'
reset_case; install; assert '.ok' 'Prepare changed-consent enable'
jq --arg sha "$B" '.plugins[0].listingValidatedCommit=$sha | .plugins[0].verificationCommit=$sha' "$tmp/catalog-good.json" > "$tmp/catalog.json"
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Listing revision changed since consent prevents standalone enable'
[[ ! -s $tmp/enabled-content && $("$real_git" -C "$installed" rev-parse HEAD) == "$A" ]]
reset_case
jq '.plugins[0].verificationSnapshotStatus="unverified"' "$tmp/catalog-good.json" > "$tmp/catalog-next.json"
touch "$tmp/change-catalog"; install; refused 'Catalog changed before publication'
reset_case; touch "$tmp/race-config"; install; refused 'Dormant references rechecked before publication'
reset_case
printf '{"plugins":[{"id":"test.pinned"}]}' > "$HOME/.config/omarchy/shell.json"
install; refused 'Dormant references block initial install'
reset_case; touch "$tmp/race-destination"; install
assert '.ok==false' 'Concurrent destination cannot be overwritten'
[[ $(cat "$installed/retain") == 'existing content' && ! -e $installed/.git ]]
reset_case; mkdir -p "$installed"; printf 'existing content' > "$installed/retain"; install
assert '.ok==false' 'Existing destination cannot be overwritten'
[[ $(cat "$installed/retain") == 'existing content' ]]
reset_case
mkdir -p "$HOME/.config/omarchy/plugins/duplicate"
cp "$tmp/source/manifest.json" "$HOME/.config/omarchy/plugins/duplicate/manifest.json"
install; assert '.ok==false' 'Duplicate discovered ID blocks install'; [[ ! -e $installed ]]
rm -rf "$HOME/.config/omarchy/plugins/duplicate"
reset_case
mkdir -p "$tmp/development"
jq '.id="test.development"' "$tmp/source/manifest.json" > "$tmp/development/manifest.json"
cp "$tmp/source/Fixture.qml" "$tmp/development/Fixture.qml"
ln -s "$tmp/development" "$HOME/.config/omarchy/plugins/development"
install; assert '.ok' 'Unrelated development symlink does not block pinned install'
[[ -L $HOME/.config/omarchy/plugins/development ]]
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok and any(.plugins[];.id=="test.pinned" and .enabled)' 'Unrelated development symlink does not block reviewed enable'
cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
reset_case
jq '.id="test.pinned"' "$tmp/source/manifest.json" > "$tmp/development/manifest.json"
install; assert '.ok==false' 'Duplicate ID through development symlink blocks install'
[[ ! -e $installed && -L $HOME/.config/omarchy/plugins/development ]]
rm "$HOME/.config/omarchy/plugins/development"
reset_case
# Wrong manifest at an otherwise eligible immutable commit.
"$real_git" -C "$tmp/source" checkout --detach "$A" >/dev/null 2>&1
jq '.id="test.wrong"' "$tmp/source/manifest.json" > "$tmp/manifest"
cp "$tmp/manifest" "$tmp/source/manifest.json"
"$real_git" -C "$tmp/source" add .
"$real_git" -C "$tmp/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm wrong
wrong=$("$real_git" -C "$tmp/source" rev-parse HEAD)
jq --arg sha "$wrong" '.plugins[0].listingValidatedCommit=$sha | .plugins[0].verificationCommit=$sha' "$tmp/catalog-good.json" > "$tmp/catalog.json"
run install test.pinned "$repo" "$wrong" --consent-unsandboxed; refused 'Wrong manifest ID never publishes'
reset_case
mkdir -p "$XDG_STATE_HOME/oma_plug_sea"
rm -f "$XDG_STATE_HOME/oma_plug_sea/action.lock"
printf 'lock sentinel' > "$tmp/lock-target"
ln -s "$tmp/lock-target" "$XDG_STATE_HOME/oma_plug_sea/action.lock"
install; refused 'Symlinked action lock refused'; [[ $(cat "$tmp/lock-target") == 'lock sentinel' ]]
rm "$XDG_STATE_HOME/oma_plug_sea/action.lock"
for path in plugins state; do
  reset_case
  if [[ $path == plugins ]]; then target="$HOME/.config/omarchy/plugins"; else target="$XDG_STATE_HOME/oma_plug_sea"; fi
  mv "$target" "$tmp/saved-$path"; mkdir "$tmp/target-$path"; ln -s "$tmp/target-$path" "$target"
  install; assert '.ok==false' "Symlinked $path directory refused"
  [[ -z $(find "$tmp/target-$path" -mindepth 1 -print -quit) ]]
  rm "$target"; mv "$tmp/saved-$path" "$target"
done
reset_case; touch "$tmp/rescan-fail"; install
assert '.ok==false' 'Post-publication rescan failure reports failure'
[[ -d $installed/.git && ! -s $tmp/enabled-content ]]
jq -e '.retained=="configuration"' "$HOME/.config/omarchy/shell.json" >/dev/null
reset_case; touch "$tmp/enable-fail"
run install-enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Enable failure retains disabled installation'
[[ -d $installed/.git && $(cat "$tmp/enabled.json") == '[]' ]]
jq -e '.retained=="configuration"' "$HOME/.config/omarchy/shell.json" >/dev/null
reset_case; install; assert '.ok' 'Prepare obsolete-update check'
cp "$installed/Fixture.qml" "$tmp/before-content"
cp "$tmp/fetches" "$tmp/before-fetches"
cp "$HOME/.config/omarchy/shell.json" "$tmp/before-config"
run update test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Obsolete update fails without mutation'
cmp "$tmp/fetches" "$tmp/before-fetches"
cmp "$installed/Fixture.qml" "$tmp/before-content"
cmp "$HOME/.config/omarchy/shell.json" "$tmp/before-config"
# Recovery remains possible after reviewed contents are changed.
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok' 'Prepare enabled recovery fixture'
printf '\n// user edit retained for disable\n' >> "$installed/Fixture.qml"
run disable test.pinned
assert '.ok and any(.plugins[];.id=="test.pinned" and (.enabled|not))' 'Recovery disable does not require pristine contents'
[[ $(cat "$installed/Fixture.qml") == *'user edit retained for disable'* ]]
run remove test.pinned --confirm-remove
assert '.ok and all(.plugins[];.id!="test.pinned")' 'Recovery removal uses real platform command'
[[ ! -e $installed ]]
# First-party enable bypasses community requirements; removal stays blocked.
omarchy-shell shell listPlugins > "$tmp/first-party-list"
first_party=$(jq -er '[.[]|select(.firstParty and (.kinds|index("panel"))!=null)][0].id' "$tmp/first-party-list")
run disable "$first_party"
assert '.ok' 'First-party disable remains available'
run enable "$first_party" --consent-unsandboxed
assert '.ok' 'First-party enable needs no community snapshot/source inspection'
run remove "$first_party" --confirm-remove
assert '.ok==false' 'First-party removal remains prohibited'
# Numeric manifests use the registry's String(id), not numeric equivalence to
# the requested string. Keep the unrelated numeric source present BEFORE either
# installation path, and inspect the actual shell identities and selected bytes.
reset_case
for string_id in 1e3 01 1000; do
  case $string_id in
    1e3|1000) numeric_id=1000 ;;
    01) numeric_id=1 ;;
  esac
  "$real_git" -C "$tmp/source" checkout --detach "$A" >/dev/null 2>&1
  jq --arg id "$string_id" '.id=$id' "$tmp/source/manifest.json" > "$tmp/manifest"
  cp "$tmp/manifest" "$tmp/source/manifest.json"
  "$real_git" -C "$tmp/source" add .
  "$real_git" -C "$tmp/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm "Reviewed string ID $string_id"
  numeric_a=$("$real_git" -C "$tmp/source" rev-parse HEAD)
  printf 'import QtQuick\nItem { property string revision: "UNREVIEWED NUMERIC UPSTREAM" }\n' > "$tmp/source/Fixture.qml"
  "$real_git" -C "$tmp/source" add .
  "$real_git" -C "$tmp/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm "Unreviewed upstream $string_id"
  numeric_b=$("$real_git" -C "$tmp/source" rev-parse HEAD)
  jq --arg id "$string_id" --arg a "$numeric_a" --arg b "$numeric_b" \
    '.plugins[0] |= (.id=$id | .listingValidatedCommit=$a | .verificationCommit=$a | .upstreamObservedCommit=$b)' \
    "$tmp/catalog-good.json" > "$tmp/numeric-catalog.json"
  installed="$HOME/.config/omarchy/plugins/$string_id"
  cp "$tmp/numeric-catalog.json" "$tmp/catalog.json"
  mkdir -p "$HOME/.config/omarchy/plugins/numeric"
  jq --argjson id "$numeric_id" '.id=$id' "$tmp/source/manifest.json" > "$HOME/.config/omarchy/plugins/numeric/manifest.json"
  printf 'import QtQuick\nItem { property string revision: "UNREVIEWED NUMERIC SHADOW" }\n' > "$HOME/.config/omarchy/plugins/numeric/Fixture.qml"
  omarchy-shell shell rescanPlugins
  run install "$string_id" "$repo" "$numeric_a" --consent-unsandboxed
  if [[ $string_id == 1000 ]]; then
    assert '.ok==false' 'Numeric 1000 genuinely collides with requested string 1000 before installation'
    [[ ! -e $installed && ! -s $tmp/enabled-content ]]
    cmp "$HOME/.config/omarchy/plugins/numeric/Fixture.qml" <(printf 'import QtQuick\nItem { property string revision: "UNREVIEWED NUMERIC SHADOW" }\n')
    run install-enable "$string_id" "$repo" "$numeric_a" --consent-unsandboxed
    assert '.ok==false' 'Genuine numeric 1000 duplicate also refuses Install & enable'
    [[ ! -e $installed && ! -s $tmp/enabled-content ]]
    rm -rf "$HOME/.config/omarchy/plugins/numeric"
    omarchy-shell shell rescanPlugins
    run install "$string_id" "$repo" "$numeric_a" --consent-unsandboxed
    assert '.ok and any(.plugins[];.id=="1000" and (.enabled|not))' 'Unique string 1000 installs pristine and disabled'
    [[ ! -s $tmp/enabled-content ]]
    "$root/bin/oma-plug-sea-local" > "$tmp/result"
    assert "any(.plugins[];.id==\"1000\" and .headCommit==\"$numeric_a\" and .detached and .clean and .localPath==\"$installed\")" 'Unique string 1000 has exact reviewed canonical provenance before the numeric shadow'
    mkdir -p "$HOME/.config/omarchy/plugins/zz-numeric-shadow"
    jq '.id=1000' "$tmp/source/manifest.json" > "$HOME/.config/omarchy/plugins/zz-numeric-shadow/manifest.json"
    printf 'import QtQuick\nItem { property string revision: "UNREVIEWED NUMERIC SHADOW" }\n' > "$HOME/.config/omarchy/plugins/zz-numeric-shadow/Fixture.qml"
    omarchy-shell shell rescanPlugins
    "$real_node" "$registry_harness" "$tmp" "$platform" source "$string_id" > "$tmp/result"
    assert ".ok and .sourceDir==\"$HOME/.config/omarchy/plugins/zz-numeric-shadow\"" 'Actual registry selects the valid winning numeric 1000 shadow'
    omarchy-shell shell listPlugins > "$tmp/result"
    assert '([.[]|select(.firstParty|not)|.id])==["1000"]' 'Actual registry deduplicates numeric and string 1000 to the same identity'
    "$root/bin/oma-plug-sea-local" > "$tmp/result"
    assert 'any(.plugins[];.id=="1000" and .headCommit=="" and .localPath=="" and (.clean|not))' 'Genuine numeric duplicate suppresses canonical provenance'
    run enable "$string_id" "$repo" "$numeric_a" --consent-unsandboxed
    assert '.ok==false' 'Winning numeric 1000 shadow refuses standalone enable of string 1000'
    [[ ! -s $tmp/enabled-content && -d $installed/.git ]]
    [[ -z $("$real_git" -C "$installed" status --porcelain --untracked-files=all) ]]
    cmp "$HOME/.config/omarchy/plugins/zz-numeric-shadow/Fixture.qml" <(printf 'import QtQuick\nItem { property string revision: "UNREVIEWED NUMERIC SHADOW" }\n')
  else
    assert ".ok and any(.plugins[];.id==\"$string_id\" and (.enabled|not))" "Numeric $numeric_id present before install does not block string $string_id"
    [[ ! -s $tmp/enabled-content ]]
    omarchy-shell shell listPlugins > "$tmp/result"
    assert "([.[]|select(.firstParty|not)|.id]|sort)==([\"$numeric_id\",\"$string_id\"]|sort)" "Actual registry keeps numeric $numeric_id and string $string_id as distinct identities"
    "$root/bin/oma-plug-sea-local" > "$tmp/result"
    assert "any(.plugins[];.id==\"$string_id\" and .headCommit==\"$numeric_a\" and .detached and .clean and .localPath==\"$installed\" and (.enabled|not))" "Disabled string $string_id exposes exact reviewed canonical provenance"
    run enable "$string_id" "$repo" "$numeric_a" --consent-unsandboxed
    assert ".ok and any(.plugins[];.id==\"$string_id\" and .enabled and .headCommit==\"$numeric_a\" and .detached and .clean)" "Distinct numeric $numeric_id permits pristine standalone enable of string $string_id"
    cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$numeric_a:Fixture.qml")
    reset_case
    cp "$tmp/numeric-catalog.json" "$tmp/catalog.json"
    run install-enable "$string_id" "$repo" "$numeric_a" --consent-unsandboxed
    assert ".ok and any(.plugins[];.id==\"$string_id\" and .enabled and .headCommit==\"$numeric_a\" and .detached and .clean)" "Distinct numeric $numeric_id also permits reviewed Install & enable of string $string_id"
    cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$numeric_a:Fixture.qml")
  fi
  [[ $("$real_git" -C "$installed" rev-parse HEAD) == "$numeric_a" ]]
  ! "$real_git" -C "$installed" symbolic-ref -q HEAD
  cmp "$installed/Fixture.qml" <("$real_git" -C "$tmp/source" show "$numeric_a:Fixture.qml")
  cmp "$installed/manifest.json" <("$real_git" -C "$tmp/source" show "$numeric_a:manifest.json")
  [[ $("$real_git" -C "$installed" remote get-url origin) == "$repo" ]]
  reset_case
  rm -rf "$HOME/.config/omarchy/plugins/"{numeric,zz-numeric-shadow}
done
# Preserve this decimal spelling: jq rewriting the manifest would remove the
# unrelated subnormal input that exercises production numeric ID inspection.
# Restore the original test.pinned A/B history after the numeric-string loops.
installed="$HOME/.config/omarchy/plugins/test.pinned"
reset_case
"$real_git" -C "$tmp/source" checkout --detach "$B" >/dev/null 2>&1
slow_numeric="$HOME/.config/omarchy/plugins/numeric-subnormal"
mkdir -p "$slow_numeric"
cat > "$slow_numeric/manifest.json" <<'JSON'
{"schemaVersion":1,"id":5.0000000000000000001e-324,"name":"Inert unrelated subnormal fixture","version":"1.0.0","kinds":["panel"],"entryPoints":{"panel":"Fixture.qml"}}
JSON
cp "$slow_numeric/manifest.json" "$tmp/subnormal-manifest"
printf 'import QtQuick\nItem { property string revision: "UNRELATED SUBNORMAL" }\n' > "$slow_numeric/Fixture.qml"
omarchy-shell shell rescanPlugins
omarchy-shell shell listPlugins > "$tmp/result"
assert '([.[]|select(.firstParty|not)|.id])==["5e-324"]' 'Actual registry lists the verbatim unrelated subnormal as String identity 5e-324 before install'
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert 'any(.plugins[];.id=="5e-324")' 'Ordinary production local observation succeeds with the unrelated subnormal before install'
install
assert '.ok and any(.plugins[];.id=="test.pinned" and (.enabled|not)) and any(.plugins[];.id=="5e-324")' 'Unrelated subnormal present before install permits disabled reviewed A'
[[ ! -s $tmp/enabled-content && $("$real_git" -C "$installed" rev-parse HEAD) == "$A" ]]
! "$real_git" -C "$installed" symbolic-ref -q HEAD
[[ -z $("$real_git" -C "$installed" status --porcelain --untracked-files=all) ]]
[[ $("$real_git" -C "$installed" remote get-url origin) == "$repo" ]]
cmp "$installed/Fixture.qml" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
cmp "$installed/manifest.json" <("$real_git" -C "$tmp/source" show "$A:manifest.json")
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert "any(.plugins[];.id==\"test.pinned\" and (.enabled|not) and .headCommit==\"$A\" and .detached and .clean and .localPath==\"$installed\") and any(.plugins[];.id==\"5e-324\")" 'Subnormal coexistence exposes exact disabled reviewed A canonical provenance'
"$real_node" "$registry_harness" "$tmp" "$platform" source test.pinned > "$tmp/result"
assert ".ok and .sourceDir==\"$installed\"" 'Actual registry selects canonical reviewed A beside the unrelated subnormal'
# Add a losing but real duplicate after a successful observation. The registry
# still selects canonical A: fresh discovery, not cached authority, must reject.
mkdir -p "$HOME/.config/omarchy/plugins/aa-later-duplicate"
cp "$installed/manifest.json" "$HOME/.config/omarchy/plugins/aa-later-duplicate/manifest.json"
printf 'import QtQuick\nItem { property string revision: "UNREVIEWED LATER DUPLICATE" }\n' > "$HOME/.config/omarchy/plugins/aa-later-duplicate/Fixture.qml"
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert 'any(.plugins[];.id=="test.pinned" and .headCommit=="" and .localPath=="" and (.clean|not))' 'Later observation detects a newly added real duplicate despite prior unique provenance'
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert '.ok==false' 'Later duplicate refuses standalone enable while the unrelated subnormal remains'
[[ ! -s $tmp/enabled-content && -d $installed/.git && -d $slow_numeric ]]
rm -rf "$HOME/.config/omarchy/plugins/aa-later-duplicate"
"$root/bin/oma-plug-sea-local" > "$tmp/result"
assert "any(.plugins[];.id==\"test.pinned\" and .headCommit==\"$A\" and .detached and .clean and .localPath==\"$installed\")" 'Next observation recovers unique reviewed A provenance after duplicate removal'
run enable test.pinned "$repo" "$A" --consent-unsandboxed
assert ".ok and any(.plugins[];.id==\"test.pinned\" and .enabled and .headCommit==\"$A\" and .detached and .clean)" 'Unrelated subnormal permits standalone enable after fresh uniqueness recovery'
cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
! cmp -s "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$B:Fixture.qml")
printf '\n// user edit retained with unrelated subnormal\n' >> "$installed/Fixture.qml"
run disable test.pinned
assert '.ok and any(.plugins[];.id=="test.pinned" and (.enabled|not)) and any(.plugins[];.id=="5e-324")' 'Subnormal coexistence preserves recovery disable of modified reviewed contents'
[[ $(cat "$installed/Fixture.qml") == *'user edit retained with unrelated subnormal'* ]]
run remove test.pinned --confirm-remove
assert '.ok and all(.plugins[];.id!="test.pinned") and any(.plugins[];.id=="5e-324")' 'Recovery removal retains the unrelated subnormal source'
[[ ! -e $installed && -d $slow_numeric ]]
omarchy-shell shell listPlugins > "$tmp/result"
assert '([.[]|select(.firstParty|not)|.id])==["5e-324"]' 'Ordinary registry list still exposes only the retained subnormal after recovery removal'
run disable "$first_party"
assert '.ok' 'First-party disable remains available beside the unrelated subnormal'
run enable "$first_party" --consent-unsandboxed
assert '.ok' 'First-party enable remains available beside the unrelated subnormal'
reset_case
run install-enable test.pinned "$repo" "$A" --consent-unsandboxed
assert ".ok and any(.plugins[];.id==\"test.pinned\" and .enabled and .headCommit==\"$A\" and .detached and .clean and .localPath==\"$installed\") and any(.plugins[];.id==\"5e-324\")" 'Unrelated subnormal present before Install & enable permits exact reviewed A activation'
cmp "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$A:Fixture.qml")
! cmp -s "$tmp/enabled-content" <("$real_git" -C "$tmp/source" show "$B:Fixture.qml")
cmp "$slow_numeric/manifest.json" "$tmp/subnormal-manifest"

printf 'PASS: %s pinned-install assertions (real Git/validator/catalog/registry selection and shell list; transport, IPC, activation simulated; no live QML executes)\n' "$pass"
