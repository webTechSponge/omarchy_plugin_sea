#!/usr/bin/env bash
# Real Git object/content checks and installed platform validation/discovery.
# Only HTTPS fetch transport and shell IPC are simulated; no live QML executes.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
platform=${OMARCHY_PATH:-/usr/share/omarchy}
real_git=$(command -v git)
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
printf '#!/usr/bin/env bash\nset -euo pipefail\nfixture=%q\n' "$tmp" > "$tmp/bin/omarchy-shell"
cat >> "$tmp/bin/omarchy-shell" <<'WRAPPER'
[[ $1 == shell ]] || exit 98
case $2 in
 ping) echo ok ;;
 rescanPlugins) [[ ! -e $fixture/rescan-fail ]] ;;
 listPlugins)
   omarchy-plugin-catalog | jq --slurpfile enabled "$fixture/enabled.json" '[.[]|select(.firstParty|not)|.id as $id|.enabled=($enabled[0]|index($id) != null)|.active=.enabled|.canDisable=true]'
   ;;
 *) exit 98 ;;
esac
WRAPPER
# Preserve real platform validate/catalog/list. Enable changes observable shell
# state only, recording the actual entrypoint bytes at the enable boundary.
printf '#!/usr/bin/env bash\nset -euo pipefail\nfixture=%q\nplatform=%q\n' "$tmp" "$platform" > "$tmp/bin/omarchy"
cat >> "$tmp/bin/omarchy" <<'WRAPPER'
[[ $1 == plugin ]] || exit 98
case $2 in
 enable)
  [[ ! -e $fixture/enable-fail ]] || exit 72
  cat "$HOME/.config/omarchy/plugins/$3/Fixture.qml" >> "$fixture/enabled-content"
  jq --arg id "$3" '.+[$id]|unique' "$fixture/enabled.json" > "$fixture/enabled-next.json"
  mv "$fixture/enabled-next.json" "$fixture/enabled.json"
  ;;
 *) exec "$platform/bin/omarchy" "$@" ;;
esac
WRAPPER
chmod +x "$tmp/bin/"*
printf '[]' > "$tmp/enabled.json"
printf '{"retained":"configuration"}' > "$HOME/.config/omarchy/shell.json"
cat > "$tmp/source/manifest.json" <<'JSON'
{"schemaVersion":1,"id":"test.pinned","name":"Inert reviewed fixture","version":"1.0.0","kinds":["panel"],"entryPoints":{"panel":"Fixture.qml"}}
JSON
printf 'import QtQuick\nItem { property string revision: "A" }\n' > "$tmp/source/Fixture.qml"
printf '*.ignored\n' > "$tmp/source/.gitignore"
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
  rm -f "$tmp/"{fetch-fail,network-fail,change-catalog,race-destination,race-config,rescan-fail,enable-fail,enabled-content}
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
# Mutations cannot be repaired/reset silently to permit enable.
for mutation in tracked untracked ignored head branch origin manifest symlink gitlink config index writable; do
  reset_case; install; assert '.ok' 'Prepare disabled checkout'
  case $mutation in
    tracked) printf '\n// user edit\n' >> "$installed/Fixture.qml" ;;
    untracked) printf 'extra code\n' > "$installed/Extra.qml" ;;
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
printf 'PASS: %s pinned-install assertions (real Git/validator/catalog; transport and shell state simulated)\n' "$pass"
