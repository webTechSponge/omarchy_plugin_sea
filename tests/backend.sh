#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
export TEST_ROOT="$tmp" TEST_FIXTURE="$ROOT/fixtures/catalog.json"
export TEST_REAL_GIT=$(command -v git)
mkdir -p "$tmp/mock" "$HOME/.config/omarchy/plugins"
export PATH="$tmp/mock:$PATH"
cat >"$tmp/mock/curl" <<'MOCK'
#!/usr/bin/env bash
[[ ${TEST_NETWORK_FAIL:-0} == 0 ]] || { echo 'simulated network failure' >&2; exit 7; }
headers=""; output=""; head=false; status=false
while (( $# )); do
  case $1 in
    -D) headers=$2; shift ;;
    -o) output=$2; shift ;;
    --head) head=true ;;
    -w) status=true; shift ;;
    -H) printf '%s\n' "$2" >>"$TEST_ROOT/conditions"; shift ;;
  esac
  shift
done
if [[ -n $headers ]]; then
  printf 'HTTP/2 %s\r\n' "${TEST_HEAD_STATUS:-200}" >"$headers"
  if [[ ${TEST_NO_VALIDATORS:-0} == 0 ]]; then
    printf 'ETag: %s\r\nLast-Modified: %s\r\n' "${TEST_ETAG:-\"fixture-v1\"}" "${TEST_MODIFIED:-Sat, 05 Sep 2026 19:02:32 GMT}" >>"$headers"
  fi
  printf '\r\n' >>"$headers"
fi
[[ $head == true || -z $output ]] || cp "${TEST_CATALOG:-$TEST_FIXTURE}" "$output"
[[ $status == false ]] || printf '%s' "${TEST_HEAD_STATUS:-200}"
exit 0
MOCK
cat >"$tmp/mock/omarchy-shell" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_ROOT/ipc"
[[ ${TEST_SHELL_FAIL:-0} == 0 ]] || exit 1
echo ok
MOCK
cat >"$tmp/mock/git" <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == ls-remote && $2 == --get-url ]]; then
 if [[ ${TEST_REAL_URL_RESOLUTION:-0} == 1 ]]; then exec "$TEST_REAL_GIT" "$@"; fi
 printf '%s\n' "${TEST_INSTALL_EFFECTIVE_SOURCE:-${@: -1}}"; exit
fi
if [[ $3 == config ]]; then echo "${TEST_GIT_ORIGIN:-https://github.com/test/weather}"; exit; fi
if [[ $3 == remote && $4 == get-url ]]; then
 printf '%s\n' "${TEST_EFFECTIVE_ORIGIN:-${TEST_GIT_ORIGIN:-https://github.com/test/weather}}"; exit
fi
if [[ $3 == rev-parse ]]; then
 if [[ $4 == FETCH_HEAD && ${TEST_REV_MISMATCH:-0} == 1 ]]; then echo different; else echo verified-revision; fi
 exit
fi
exit 1
MOCK
cat >"$tmp/mock/omarchy" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ $1 == plugin ]] || exit 2
shift
if [[ $1 == list ]]; then
 [[ ${TEST_LOCAL_FAIL:-0} == 0 ]] || { echo 'shell stopped' >&2; exit 1; }
 cat "$TEST_ROOT/local.json"; exit
fi
printf '%s\n' "$@" >>"$TEST_ROOT/argv"
[[ ${TEST_ACTION_FAIL:-0} == 0 ]] || { echo 'simulated Git/validation failure' >&2; exit 9; }
sleep "${TEST_ACTION_DELAY:-0}"
action=$1; id=${2:-}
[[ ${TEST_FALSE_SUCCESS:-0} == 0 ]] || exit 0
case $action in
add)
 id=${TEST_INSTALL_ID:-test.weather}
 mkdir -p "$HOME/.config/omarchy/plugins/$id/.git"
 printf '{"id":"%s","version":"1.0","barWidget":{"defaultSection":"right"}}' "$id" >"$HOME/.config/omarchy/plugins/$id/manifest.json"
 jq --arg id "$id" '.+[{id:$id,name:"Weather",enabled:false,active:false,firstParty:false,canDisable:true,kinds:["bar-widget"]}]' "$TEST_ROOT/local.json" >"$TEST_ROOT/new.json"
 ;;
enable|disable)
 jq --arg id "$id" --argjson enabled "$([[ $action == enable ]] && echo true || echo false)" 'map(if .id==$id then .enabled=$enabled else . end)' "$TEST_ROOT/local.json" >"$TEST_ROOT/new.json"
 ;;
remove)
 rm -rf -- "$HOME/.config/omarchy/plugins/$id"
 jq --arg id "$id" 'map(select(.id!=$id))' "$TEST_ROOT/local.json" >"$TEST_ROOT/new.json"
 ;;
update) cp "$TEST_ROOT/local.json" "$TEST_ROOT/new.json" ;;
*) exit 2 ;;
esac
mv "$TEST_ROOT/new.json" "$TEST_ROOT/local.json"
echo "mock action $action completed"
MOCK
chmod +x "$tmp/mock/"*
printf '[]' >"$tmp/local.json"
printf '{"retained":"config"}' >"$HOME/.config/omarchy/shell.json"
pass=0
assert() { if ! jq -e "$2" "$1" >/dev/null; then echo "FAIL: $3" >&2; cat "$1" >&2; exit 1; fi; pass=$((pass+1)); }
cat_helper="$ROOT/bin/oma-plug-sea-catalog"
local_helper="$ROOT/bin/oma-plug-sea-local"
act="$ROOT/bin/oma-plug-sea-action"
"$cat_helper" refresh >"$tmp/out"
assert "$tmp/out" '.ok and (.stale|not) and (.plugins|length)==3' 'real-schema fixture normalization'
assert "$tmp/out" '.sourceValidators.etag=="\"fixture-v1\"" and .sourceValidators.lastModified=="Sat, 05 Sep 2026 19:02:32 GMT" and (.sourceHash|length)==64' 'refresh persists HTTP validators and content digest'
cp "$XDG_CACHE_HOME/oma_plug_sea/catalog.json" "$tmp/good"
"$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and (.refreshNeeded|not) and .error=="" and (.checkedAt|endswith("Z"))' 'unchanged source validators'
[[ $(tail -1 "$tmp/conditions") == 'If-None-Match: "fixture-v1"' ]]
TEST_HEAD_STATUS=304 "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and (.refreshNeeded|not)' 'conditional HEAD not modified'
TEST_ETAG='"fixture-v2"' "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and .refreshNeeded' 'new ETag indicates refresh'
TEST_NETWORK_FAIL=1 "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok==false and .refreshNeeded==false and (.error|contains("simulated network"))' 'poll failure never falsely indicates a newer catalog'
TEST_HEAD_STATUS=404 "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok==false and (.refreshNeeded|not) and (.error|contains("HTTP 404"))' 'HTTP failure is not a newer catalog'
TEST_NO_VALIDATORS=1 "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and (.refreshNeeded|not)' 'missing validators compares unchanged content'
TEST_HEAD_STATUS=405 "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and (.refreshNeeded|not)' 'unsupported HEAD falls back to content comparison'
jq '.plugins[0].description="New source description"' "$TEST_FIXTURE" >"$tmp/changed.json"
TEST_NO_VALIDATORS=1 TEST_CATALOG="$tmp/changed.json" "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and .refreshNeeded' 'content comparison detects changed data'
printf '{invalid' >"$tmp/poll-invalid"
TEST_NO_VALIDATORS=1 TEST_CATALOG="$tmp/poll-invalid" "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok==false and (.refreshNeeded|not)' 'malformed poll content does not imply a valid update'
cmp "$tmp/good" "$XDG_CACHE_HOME/oma_plug_sea/catalog.json"
jq 'del(.sourceValidators.etag)' "$tmp/good" >"$XDG_CACHE_HOME/oma_plug_sea/catalog.json"
TEST_MODIFIED='Sun, 06 Sep 2026 19:02:32 GMT' "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and .refreshNeeded' 'Last-Modified works without ETag'
[[ $(tail -1 "$tmp/conditions") == 'If-Modified-Since: Sat, 05 Sep 2026 19:02:32 GMT' ]]
jq 'del(.sourceValidators,.sourceHash)' "$tmp/good" >"$XDG_CACHE_HOME/oma_plug_sea/catalog.json"
cp "$XDG_CACHE_HOME/oma_plug_sea/catalog.json" "$tmp/legacy"
"$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and (.refreshNeeded|not)' 'legacy cache compares normalized data'
TEST_CATALOG="$tmp/changed.json" "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and .refreshNeeded' 'legacy cache detects normalized data changes'
cmp "$tmp/legacy" "$XDG_CACHE_HOME/oma_plug_sea/catalog.json"
cp "$tmp/good" "$XDG_CACHE_HOME/oma_plug_sea/catalog.json"
TEST_NETWORK_FAIL=1 "$cat_helper" refresh >"$tmp/out"
assert "$tmp/out" '.ok and .stale and (.error|contains("simulated network"))' 'network stale fallback'
cmp "$tmp/good" "$XDG_CACHE_HOME/oma_plug_sea/catalog.json"
exec 8>"$XDG_CACHE_HOME/oma_plug_sea/catalog.lock"
flock -n 8
"$cat_helper" refresh >"$tmp/out"
assert "$tmp/out" '.ok and .stale and (.error|contains("Another"))' 'concurrent catalog refresh retains saved data'
flock -u 8
printf '{broken' >"$tmp/broken"
TEST_CATALOG="$tmp/broken" "$cat_helper" refresh >"$tmp/out"
assert "$tmp/out" '.ok and .stale and (.error|contains("rejected"))' 'malformed catalog retained'
mkdir -p "$tmp/evil-target" "$tmp/evil-cache"
ln -s "$tmp/evil-target" "$tmp/evil-cache/oma_plug_sea"
XDG_CACHE_HOME="$tmp/evil-cache" "$cat_helper" refresh >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and (.error|contains("Cache directory unavailable"))' 'symlinked cache dir refused with last-good fallback'
[[ $(find "$tmp/evil-target" -mindepth 1 | wc -l) == 0 ]]
pass=$((pass+1))
TEST_ETAG=$'"crlf\rv1"' "$cat_helper" refresh >"$tmp/out"
assert "$tmp/out" '.ok and .sourceValidators.etag=="\"crlfv1\""' 'CR stripped from persisted ETag'
: >"$tmp/conditions"
TEST_ETAG=$'"crlf\rv1"' "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and .refreshNeeded' 'conditional check still functions after sanitization'
[[ $(wc -l <"$tmp/conditions") == 1 ]]
[[ $(tail -1 "$tmp/conditions") == 'If-None-Match: "crlfv1"' ]]
pass=$((pass+1))
pass=$((pass+1))
printf '{"plugins":[{"id":"../bad","name":"Bad"}]}' >"$tmp/broken"
if "$cat_helper" normalize "$tmp/broken" >/dev/null 2>&1; then echo 'FAIL invalid ID' >&2; exit 1; fi
pass=$((pass+1))
printf '{"plugins":[{"id":"test.bad","name":"Bad","repo":"https://github.com/x/r;touch /tmp/PWN","installAvailable":true,"previewImage":"file:///etc/passwd"}]}' >"$tmp/broken"
"$cat_helper" normalize "$tmp/broken" >"$tmp/out"
assert "$tmp/out" '.plugins[0] | .installAvailable==false and .repo=="" and .previewImage==""' 'hostile URLs disarmed'
printf '{"plugins":[{"id":"test.duplicate","name":"One"},{"id":"test.duplicate","name":"Two"}]}' >"$tmp/broken"
if "$cat_helper" normalize "$tmp/broken" >/dev/null 2>&1; then echo 'FAIL duplicate IDs' >&2; exit 1; fi
pass=$((pass+1))
printf '{"plugins":[{"id":"test.partial"}]}' >"$tmp/broken"
if "$cat_helper" normalize "$tmp/broken" >/dev/null 2>&1; then echo 'FAIL partial catalog' >&2; exit 1; fi
pass=$((pass+1))
# Malformed optional status disables just that listing instead of crashing jq.
for bad_status in 7 true false '{}' '[]'; do
  jq --argjson status "$bad_status" '.plugins[0].status=$status | .plugins[0].installAvailable=true' "$TEST_FIXTURE" >"$tmp/status.json"
  "$cat_helper" normalize "$tmp/status.json" >"$tmp/out"
  assert "$tmp/out" '.ok and (.plugins|length)==3 and (.plugins[0] | .installAvailable==false and .status=="" and (.installNote|contains("invalid type")))' "invalid status $bad_status safely disables listing"
done
for status in null '"active"'; do
  jq --argjson status "$status" '.plugins[0].status=$status | .plugins[0].installAvailable=true' "$TEST_FIXTURE" >"$tmp/status.json"
  "$cat_helper" normalize "$tmp/status.json" >"$tmp/out"
  assert "$tmp/out" '.ok and .plugins[0].installAvailable' "supported status $status preserves listing availability"
done
jq 'del(.plugins[0].status) | .plugins[0].installAvailable=true' "$TEST_FIXTURE" >"$tmp/status.json"
"$cat_helper" normalize "$tmp/status.json" >"$tmp/out"
assert "$tmp/out" '.ok and .plugins[0].installAvailable' 'missing optional status preserves listing availability'
jq '.plugins=[{id:"test.weather",name:"Weather",repo:"https://github.com/test/weather",installAvailable:true}]' "$TEST_FIXTURE" >"$tmp/install.json"
TEST_CATALOG="$tmp/install.json" "$cat_helper" refresh >/dev/null
"$act" install test.weather https://github.com/test/weather >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("consent"))' 'missing consent'
[[ ! -e $tmp/argv ]]
"$act" install '../bad' https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("ID"))' 'action invalid ID'
"$act" install test.weather 'https://github.com/test/weather;echo BAD' --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("HTTPS"))' 'action injection URL rejected'
"$act" install test.weather https://github.com/test/different --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("selected source"))' 'consented source must match selected listing'
TEST_LOCAL_FAIL=1 "$act" install test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("shell"))' 'stopped shell safe failure'
printf '{"plugins":[{"id":"test.dormant"}]}' >"$HOME/.config/omarchy/shell.json"
"$act" install test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("undiscovered"))' 'dormant references cannot auto-enable cloned code'
printf '{"retained":"config"}' >"$HOME/.config/omarchy/shell.json"
# Real Git resolves an approved HTTPS URL to a local transport through insteadOf.
# The helper must stop before delegating any add/enable action.
"$TEST_REAL_GIT" config --file "$tmp/rewrite.gitconfig" url."file://$tmp/unapproved/".insteadOf https://github.com/test/
resolved=$(GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/rewrite.gitconfig" "$TEST_REAL_GIT" ls-remote --get-url -- https://github.com/test/weather)
[[ $resolved == "file://$tmp/unapproved/weather" ]]
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/rewrite.gitconfig" TEST_REAL_URL_RESOLUTION=1 "$act" install-enable test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("Git rewrites"))' 'real Git insteadOf transport bypass rejected before add'
[[ ! -e $tmp/argv ]]
"$TEST_REAL_GIT" config --file "$tmp/rewrite.gitconfig" --unset-all url."file://$tmp/unapproved/".insteadOf
"$TEST_REAL_GIT" config --file "$tmp/rewrite.gitconfig" url.https://github.com/unapproved/.insteadOf https://github.com/test/
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/rewrite.gitconfig" TEST_REAL_URL_RESOLUTION=1 "$act" install test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("different repository"))' 'real Git HTTPS-to-HTTPS rewrite also rejected'
[[ ! -e $tmp/argv ]]
TEST_ACTION_FAIL=1 "$act" install test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.stderr|contains("validation failure"))' 'subprocess diagnostics'
"$act" install test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok and any(.plugins[];.id=="test.weather" and .enabled==false)' 'install defaults disabled'
mkdir -p "$HOME/.config/omarchy/plugins/test.weather/.git"
cp "$tmp/argv" "$tmp/before-update"
"$act" update test.weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("approved source"))' 'update requires approved source'
TEST_GIT_ORIGIN=https://github.com/test/changed "$act" update test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("changed since consent"))' 'origin changed while consent was open rejects update'
TEST_EFFECTIVE_ORIGIN=https://github.com/test/changed "$act" update test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("changed since consent"))' 'fresh effective origin differs from earlier local snapshot'
TEST_EFFECTIVE_ORIGIN=$'https://github.com/test/weather\nhttps://github.com/test/other' "$act" update test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("effective Git origin"))' 'ambiguous origin URLs rejected'
"$act" update test.weather 'https://github.com/test/weather;echo unsafe' --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("HTTPS"))' 'update approved source remains strictly validated'
cmp "$tmp/before-update" "$tmp/argv"
pass=$((pass+1))
"$act" update test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok' 'update verifies fetched revision'
TEST_REV_MISMATCH=1 "$act" update test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("revision"))' 'update revision mismatch rejected'
[[ $(find "$XDG_STATE_HOME/oma_plug_sea" -name 'shell.json.*' | wc -l) -ge 1 ]]
for backup in "$XDG_STATE_HOME/oma_plug_sea"/shell.json.*; do cmp "$HOME/.config/omarchy/shell.json" "$backup"; done
pass=$((pass+1))
"$act" enable test.weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok and .plugins[0].enabled' 'enable postcondition'
tail -4 "$tmp/argv" >"$tmp/placement"
printf 'enable\ntest.weather\n--section\nright\n' >"$tmp/expected"
cmp "$tmp/placement" "$tmp/expected"
pass=$((pass+1))
TEST_FALSE_SUCCESS=1 "$act" disable test.weather >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("not confirmed"))' 'false CLI success rejected'
TEST_ACTION_DELAY=1 "$act" disable test.weather >"$tmp/first" &
pid=$!
sleep 0.15
"$act" disable test.weather >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("Another"))' 'concurrency rejection'
wait "$pid"
assert "$tmp/first" '.ok and (.plugins[0].enabled|not)' 'first concurrent operation finishes'
"$act" remove test.weather --confirm-remove >"$tmp/out"
assert "$tmp/out" '.ok and (.plugins|length)==0' 'remove postcondition'
"$act" disable test.weather >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("disappeared"))' 'disappeared plugin'
"$act" install-enable test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok and .plugins[0].enabled' 'install and enable separately verified'
"$act" remove test.weather --confirm-remove >/dev/null
# A clone/source changing during installation stays disabled on provenance failure.
cp "$tmp/argv" "$tmp/before-provenance"
TEST_GIT_ORIGIN=https://github.com/test/different "$act" install-enable test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("provenance differs")) and all(.plugins[];.enabled==false)' 'changed cloned raw origin refuses enable'
printf 'add\nhttps://github.com/test/weather\n--yes\n' >>"$tmp/before-provenance"
cmp "$tmp/before-provenance" "$tmp/argv"
"$act" remove test.weather --confirm-remove >/dev/null
cp "$tmp/argv" "$tmp/before-provenance"
TEST_EFFECTIVE_ORIGIN=https://github.com/test/different "$act" install-enable test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("provenance differs")) and all(.plugins[];.enabled==false)' 'changed cloned effective origin refuses enable'
printf 'add\nhttps://github.com/test/weather\n--yes\n' >>"$tmp/before-provenance"
cmp "$tmp/before-provenance" "$tmp/argv"
"$act" remove test.weather --confirm-remove >/dev/null
TEST_INSTALL_ID=test.surprise "$act" install-enable test.weather https://github.com/test/weather --consent-unsandboxed >"$tmp/out"
assert "$tmp/out" '.ok==false and all(.plugins[];.enabled==false)' 'mutable manifest ID cannot auto-enable unexpected plugin'
printf '[{"id":"test.linked","name":"Linked","enabled":false}]' >"$tmp/local.json"
mkdir -p "$HOME/.config/omarchy/plugins/test.linked"
printf '{"version":"9.9","description":"decoy"}' >"$tmp/decoy.json"
ln -sf "$tmp/decoy.json" "$HOME/.config/omarchy/plugins/test.linked/manifest.json"
"$local_helper" >"$tmp/out"
assert "$tmp/out" '.ok and ([.plugins[]|select(.id=="test.linked")]|length)==1 and all(.plugins[];select(.id=="test.linked")|.version=="" and .localPath=="")' 'symlinked manifest contributes no metadata'
rm -rf -- "$HOME/.config/omarchy/plugins/test.linked"
printf '[{"id":"test.gitlink","name":"GitLink","enabled":false}]' >"$tmp/local.json"
mkdir -p "$HOME/.config/omarchy/plugins/test.gitlink" "$tmp/decoy-git"
printf '{"version":"1.0"}' >"$HOME/.config/omarchy/plugins/test.gitlink/manifest.json"
ln -s "$tmp/decoy-git" "$HOME/.config/omarchy/plugins/test.gitlink/.git"
"$local_helper" >"$tmp/out"
assert "$tmp/out" '.ok and all(.plugins[];select(.id=="test.gitlink")|.version=="" and .localPath=="")' 'symlinked .git contributes no metadata'
rm -rf -- "$HOME/.config/omarchy/plugins/test.gitlink"
printf '[{"id":"test.dirlink","name":"DirLink","enabled":false}]' >"$tmp/local.json"
mkdir -p "$tmp/decoy-dir"
printf '{"version":"9.9","description":"decoy"}' >"$tmp/decoy-dir/manifest.json"
ln -s "$tmp/decoy-dir" "$HOME/.config/omarchy/plugins/test.dirlink"
"$local_helper" >"$tmp/out"
assert "$tmp/out" '.ok and all(.plugins[];select(.id=="test.dirlink")|.version=="" and .localPath=="")' 'symlinked plugin dir contributes no metadata'
rm -rf -- "$HOME/.config/omarchy/plugins/test.dirlink"
rm -f "$XDG_CACHE_HOME/oma_plug_sea/catalog.json"
TEST_NETWORK_FAIL=1 "$cat_helper" check >"$tmp/out"
assert "$tmp/out" '.ok and .refreshNeeded' 'no saved catalog requires refresh without making a network request'
TEST_NETWORK_FAIL=1 "$cat_helper" refresh >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and (.plugins|length)==0' 'offline without cache transparent'
echo "PASS: $pass backend behavior/security assertions"
