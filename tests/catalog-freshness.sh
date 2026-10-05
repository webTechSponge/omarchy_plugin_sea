#!/usr/bin/env bash
# Actual catalog/action helpers, real Git/platform validation/catalog and actual
# registry selection/list functions; HTTP, IPC and activation are simulated.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
platform=${OMARCHY_PATH:-/usr/share/omarchy}
real_git=$(command -v git)
export TEST_NODE=$(command -v node)
[[ -x $platform/bin/omarchy-plugin-validate && -x $platform/bin/omarchy-plugin-catalog ]] || { echo 'Installed Omarchy validator/catalog required' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config/omarchy/plugins" "$tmp/source" "$tmp/template"
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TEMPLATE_DIR="$tmp/template" LC_ALL=C
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
export PATH="$tmp/bin:$platform/bin:/usr/bin:/bin" OMARCHY_PATH="$platform" TEST_FRESHNESS_ROOT="$tmp"
export GIT_AUTHOR_DATE='2026-10-04T00:00:00Z' GIT_COMMITTER_DATE='2026-10-04T00:00:00Z'
export TEST_REGISTRY_HARNESS="$root/tests/registry-selection.cjs"
cat > "$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
fixture=$TEST_FRESHNESS_ROOT
[[ ! -e $fixture/network-fail ]] || { echo 'simulated network failure' >&2; exit 7; }
headers=''; output=''; head=false; status=false
while (( $# )); do
  case $1 in
    -D) headers=$2; shift ;;
    -o) output=$2; shift ;;
    --head) head=true ;;
    -w) status=true; shift ;;
    -H) printf '%s\n' "$2" >> "$fixture/conditions"; shift ;;
  esac
  shift
done
if [[ -n $headers ]]; then
  printf 'HTTP/2 200\r\n' > "$headers"
  if [[ ! -e $fixture/no-validators ]]; then printf 'ETag: "%s"\r\n' "$(cat "$fixture/version")" >> "$headers"; fi
  printf '\r\n' >> "$headers"
fi
if [[ $head == false && -n $output ]]; then cp "$fixture/server.json" "$output"; fi
[[ $status == false ]] || printf 200
MOCK
cat > "$tmp/bin/omarchy-shell" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == shell ]] || exit 98
case $2 in
  ping) echo ok ;;
  rescanPlugins) "$TEST_NODE" "$TEST_REGISTRY_HARNESS" "$TEST_FRESHNESS_ROOT" "$OMARCHY_PATH" rescan ;;
  listPlugins) "$TEST_NODE" "$TEST_REGISTRY_HARNESS" "$TEST_FRESHNESS_ROOT" "$OMARCHY_PATH" list ;;
  call) [[ $3 == webtechsponge.plugin-sea && $4 == activationSource ]]; "$TEST_NODE" "$TEST_REGISTRY_HARNESS" "$TEST_FRESHNESS_ROOT" "$OMARCHY_PATH" source "$5" ;;
  enablePlugin) "$TEST_NODE" "$TEST_REGISTRY_HARNESS" "$TEST_FRESHNESS_ROOT" "$OMARCHY_PATH" enable "$3" ;;
  *) exit 98 ;;
esac
MOCK
cat > "$tmp/bin/omarchy" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
exec "$OMARCHY_PATH/bin/omarchy" "$@"
MOCK
chmod +x "$tmp/bin/"*
printf '[]' > "$tmp/enabled.json"
printf '{"retained":"configuration"}' > "$HOME/.config/omarchy/shell.json"
printf '%s\n' '{"schemaVersion":1,"id":"test.freshness","name":"Inert freshness fixture","version":"1.0.0","kinds":["panel"],"entryPoints":{"panel":"Fixture.qml"}}' > "$tmp/source/manifest.json"
printf 'import QtQuick\nItem { property string revision: "A" }\n' > "$tmp/source/Fixture.qml"
"$real_git" init -q "$tmp/source"
"$real_git" -C "$tmp/source" add .
"$real_git" -C "$tmp/source" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm A
A=$("$real_git" -C "$tmp/source" rev-parse HEAD)
repo=https://github.com/test/freshness
jq -n --arg sha "$A" --arg repo "$repo" '{generatedAt:"2026-10-04T00:00:00Z",plugins:[{id:"test.freshness",name:"Inert freshness fixture",repo:$repo,installAvailable:true,upstreamAvailable:true,status:"active",repositoryLayout:"root-plugin",manifestPath:"manifest.json",verificationSnapshotStatus:"verified",verificationCommit:$sha,listingValidatedCommit:$sha}]}' > "$tmp/A.json"
jq '.plugins[0] |= (.listingValidatedCommit="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" | .verificationCommit=.listingValidatedCommit)' "$tmp/A.json" > "$tmp/B-sha.json"
jq '.generatedAt="2026-10-04T01:00:00Z" | .plugins[0].description="Unseen metadata" | .plugins += [{id:"test.new-listing",name:"Unseen listing"}]' "$tmp/A.json" > "$tmp/B-metadata.json"
cat_helper="$root/bin/oma-plug-sea-catalog"
act="$root/bin/oma-plug-sea-action"
cache="$XDG_CACHE_HOME/oma_plug_sea"
pass=0
assert() { jq -e "$1" "$tmp/result" >/dev/null || { echo "FAIL: $2" >&2; cat "$tmp/result" >&2; exit 1; }; pass=$((pass+1)); }
poll() { "$cat_helper" check > "$tmp/result"; }
unchanged() {
  cmp "$tmp/displayed.json" "$cache/catalog.json"
  [[ $(stat -c '%i:%s:%Y:%Z:%a' "$cache/catalog.lock") == "$lock_state" ]]
  [[ $(find "$cache" -maxdepth 1 -type f | wc -l) == 2 ]]
  pass=$((pass+1))
}
# Exercise the same action/baseline transitions both with validators and with
# bounded raw-content-hash fallback. No before-fix reproduction is performed.
for transport in etag hash; do
  if [[ $transport == hash ]]; then touch "$tmp/no-validators"; fi
  cp "$tmp/A.json" "$tmp/server.json"; printf A > "$tmp/version"
  "$cat_helper" refresh > "$tmp/result"
  assert '.ok and (.stale|not)' "$transport: display A"
  cp "$cache/catalog.json" "$tmp/displayed.json"
  lock_state=$(stat -c '%i:%s:%Y:%Z:%a' "$cache/catalog.lock")
  cp "$tmp/B-sha.json" "$tmp/server.json"; printf B-sha > "$tmp/version"
  poll; assert '.ok and .refreshNeeded' "$transport: changed SHA notifies before consent action"
  "$act" install test.freshness "$repo" "$A" --consent-unsandboxed > "$tmp/result"
  assert '.ok==false' "$transport: A consent refuses changed B SHA"
  [[ ! -e $HOME/.config/omarchy/plugins/test.freshness && ! -s $tmp/enabled-content ]]
  unchanged
  "$cat_helper" cached > "$tmp/result"
  assert ".plugins[0].listingValidatedCommit==\"$A\"" "$transport: refused action preserves cached A"
  poll; assert '.ok and .refreshNeeded' "$transport: refused action leaves unseen B notification"
  # Directly prepare a pristine installed A to exercise successful community
  # enable without introducing any network Git transport simulation.
  installed="$HOME/.config/omarchy/plugins/test.freshness"
  "$real_git" init -q --template="$tmp/template" "$installed"
  "$real_git" -C "$installed" remote add origin "$repo"
  "$real_git" -C "$installed" fetch -q --no-tags --no-recurse-submodules "$tmp/source" "$A"
  "$real_git" -C "$installed" checkout -q --detach "$A"
  omarchy-shell shell rescanPlugins
  cp "$tmp/B-metadata.json" "$tmp/server.json"; printf B-metadata > "$tmp/version"
  poll; assert '.ok and .refreshNeeded' "$transport: unseen metadata/listing notifies"
  "$act" enable test.freshness "$repo" "$A" --consent-unsandboxed > "$tmp/result"
  assert '.ok and any(.plugins[];.id=="test.freshness" and .enabled)' "$transport: still-eligible A snapshot enables"
  cmp "$tmp/enabled-content" "$tmp/source/Fixture.qml"
  unchanged
  poll; assert '.ok and .refreshNeeded' "$transport: successful action preserves unseen metadata/listing notification"
  touch "$tmp/network-fail"
  "$act" enable test.freshness "$repo" "$A" --consent-unsandboxed > "$tmp/result"
  assert '.ok==false' "$transport: failed fresh evidence refuses despite cached eligible A"
  rm "$tmp/network-fail"
  cmp "$tmp/enabled-content" "$tmp/source/Fixture.qml"
  unchanged
  "$cat_helper" refresh > "$tmp/result"
  assert '.ok and (.stale|not) and (.plugins|length)==2 and .plugins[0].description=="Unseen metadata"' "$transport: explicit refresh displays B"
  poll; assert '.ok and (.refreshNeeded|not)' "$transport: explicit B baseline clears no-change poll"
  rm -rf "$installed"
  rm "$tmp/enabled-content"
  rm -f "$tmp/registry.json"
  printf '[]' > "$tmp/enabled.json"
done
printf 'PASS: %s catalog freshness assertions (real Git/platform validation/catalog/registry selection and shell list; HTTP, IPC and activation simulated)\n' "$pass"
