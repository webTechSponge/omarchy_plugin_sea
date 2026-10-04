#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export TEST_ROOT="$tmp" TEST_FIXTURE="$ROOT/fixtures/catalog.json" TEST_ENGAGEMENT_FIXTURE="$ROOT/fixtures/engagement.json"
export TEST_REAL_GIT=$(command -v git)
mkdir -p "$tmp/mock" "$HOME/.config/omarchy/plugins"
export PATH="$tmp/mock:$PATH"
cat >"$tmp/mock/curl" <<'MOCK'
#!/usr/bin/env bash
[[ ${TEST_NETWORK_FAIL:-0} == 0 ]] || { echo 'simulated network failure' >&2; exit 7; }
headers=""; output=""; head=false; status=false; url=""; status_code="${TEST_HEAD_STATUS:-200}"
while (( $# )); do
  case $1 in
    -D) headers=$2; shift ;;
    -o) output=$2; shift ;;
    --head) head=true ;;
    -w) status=true; shift ;;
    -H) printf '%s\n' "$2" >>"$TEST_ROOT/conditions"; shift ;;
    *) url=$1 ;;
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
if [[ $head == true || -z $output ]]; then :;
elif [[ $url == https://api.omarchyplugins.com/v1/events ]]; then
  [[ ${TEST_HEART_FAIL:-0} == 0 ]] || { echo 'simulated heart failure' >&2; exit 7; }
  if [[ -n ${TEST_HEART_FIXTURE:-} ]]; then cp "$TEST_HEART_FIXTURE" "$output"
  else printf '%s' '{"recorded":true,"plugin":{"hearts":8}}' >"$output"; fi
  status_code=${TEST_HEART_STATUS:-${TEST_HEAD_STATUS:-200}}
elif [[ $url == https://api.omarchyplugins.com/v1/stats ]]; then
  [[ ${TEST_ENGAGEMENT_FAIL:-0} == 0 ]] || { echo 'simulated engagement failure' >&2; exit 7; }
  cp "${TEST_ENGAGEMENT_FIXTURE:-$TEST_ROOT/engagement.json}" "$output"
else
  cp "${TEST_CATALOG:-$TEST_FIXTURE}" "$output"
fi
[[ $status == false ]] || printf '%s' "$status_code"
exit 0
MOCK
cat >"$tmp/mock/omarchy-shell" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_ROOT/ipc"
[[ ${TEST_SHELL_FAIL:-0} == 0 ]] || exit 1
echo ok
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
exit 2
MOCK
chmod +x "$tmp/mock/"*
printf '[]' >"$tmp/local.json"
printf '{"retained":"config"}' >"$HOME/.config/omarchy/shell.json"
pass=0
assert() { if ! jq -e "$2" "$1" >/dev/null; then echo "FAIL: $3" >&2; cat "$1" >&2; exit 1; fi; pass=$((pass+1)); }
cat_helper="$ROOT/bin/oma-plug-sea-catalog"
local_helper="$ROOT/bin/oma-plug-sea-local"
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
  jq --argjson status "$status" '.plugins[0] |= (. + {status:$status,installAvailable:true,repo:"https://github.com/test/weather",upstreamAvailable:true,verificationSnapshotStatus:"verified",verificationCommit:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",listingValidatedCommit:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",repositoryLayout:"root-plugin",manifestPath:"manifest.json"})' "$TEST_FIXTURE" >"$tmp/status.json"
  "$cat_helper" normalize "$tmp/status.json" >"$tmp/out"
  assert "$tmp/out" '.ok and .plugins[0].installAvailable' "supported status $status preserves listing availability"
done
jq '.plugins[0] |= (. + {installAvailable:true,repo:"https://github.com/test/weather",upstreamAvailable:true,verificationSnapshotStatus:"verified",verificationCommit:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",listingValidatedCommit:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",repositoryLayout:"root-plugin",manifestPath:"manifest.json"} | del(.status))' "$TEST_FIXTURE" >"$tmp/status.json"
"$cat_helper" normalize "$tmp/status.json" >"$tmp/out"
assert "$tmp/out" '.ok and .plugins[0].installAvailable' 'missing optional status preserves listing availability'
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

# Engagement stats helper: independent of the catalog, same stale-fallback discipline.
eng="$ROOT/bin/oma-plug-sea-engagement"
TEST_ENGAGEMENT_FAIL=1 "$eng" cached >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and (.hearts|length)==0 and .error!=""' 'cached with no cache returns an empty hearts stub'
"$eng" refresh >"$tmp/out"
assert "$tmp/out" '.ok and (.stale|not) and .hearts["test.one"]==7 and .hearts["test.two"]==0' 'engagement refresh normalizes fixture'
cp "$XDG_CACHE_HOME/oma_plug_sea/engagement.json" "$tmp/eng-good"
TEST_ENGAGEMENT_FAIL=1 "$eng" refresh >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and .hearts["test.one"]==7 and (.error|contains("simulated engagement"))' 'engagement network failure keeps stale hearts'
cmp "$tmp/eng-good" "$XDG_CACHE_HOME/oma_plug_sea/engagement.json"
printf '{"schemaVersion":2,"plugins":{}}' >"$tmp/eng-bad"
TEST_ENGAGEMENT_FIXTURE="$tmp/eng-bad" "$eng" refresh >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and .hearts["test.one"]==7 and (.error|contains("rejected"))' 'malformed engagement data rejected, cache retained'
cmp "$tmp/eng-good" "$XDG_CACHE_HOME/oma_plug_sea/engagement.json"
"$eng" cached >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and .hearts["test.one"]==7' 'cached prints saved hearts as stale'
: >"$TEST_ROOT/conditions"
"$eng" heart 'bad id!' >"$tmp/out"
assert "$tmp/out" '.ok==false and .already==false and (.error|contains("Invalid"))' 'heart rejects invalid id locally'
TEST_NETWORK_FAIL=1 "$eng" heart 'also bad!' >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("Invalid"))' 'heart validation precedes network'
TEST_HEART_FAIL=1 "$eng" heart fresh.id >"$tmp/out"
assert "$tmp/out" '.ok==false and .already==false and (.error|contains("Could not send heart"))' 'heart transport failure honest'
"$eng" heart test.one >"$tmp/out"
assert "$tmp/out" '.ok==true and .recorded==true and .hearts==8' 'heart success records server total'
assert "$XDG_STATE_HOME/oma_plug_sea/hearts.json" '.["test.one"]==true' 'hearted flag persisted'
assert "$XDG_CACHE_HOME/oma_plug_sea/engagement.json" '.hearts["test.one"]==8' 'cache bumped to server total'
grep -q -F 'Origin: https://plugins.omarchy.org' "$TEST_ROOT/conditions" || { echo 'FAIL: heart Origin header' >&2; exit 1; }
pass=$((pass+1))
grep -q -F 'Content-Type: application/json' "$TEST_ROOT/conditions" || { echo 'FAIL: heart content type' >&2; exit 1; }
pass=$((pass+1))
TEST_NETWORK_FAIL=1 "$eng" heart test.one >"$tmp/out"
assert "$tmp/out" '.ok==false and .already==true' 'no double-send while offline'
printf '%s' '{"recorded":false}' >"$tmp/heart-rate"
: >"$tmp/heart-empty"
printf '%s' '{"recorded":true}' >"$tmp/heart-nototal"
TEST_HEART_STATUS=202 TEST_HEART_FIXTURE="$tmp/heart-rate" "$eng" heart test.two >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("rate"))' 'recorded:false maps to rate message'
TEST_HEART_STATUS=429 TEST_HEART_FIXTURE="$tmp/heart-empty" "$eng" heart test.two >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("429"))' 'HTTP 429 reported honestly'
TEST_HEART_STATUS=200 TEST_HEART_FIXTURE="$tmp/heart-nototal" "$eng" heart test.two >"$tmp/out"
assert "$tmp/out" '.ok==true and .hearts==null' 'recorded:true without total still succeeds'
"$eng" hearts-state >"$tmp/out"
assert "$tmp/out" '.ok==true and .hearted["test.one"]==true and .hearted["test.two"]==true and (.hearted|has("fresh.id")|not)' 'hearts-state lists hearted ids'
mkdir -p "$tmp/eng-evil"
printf '%s' '{"schemaVersion":1,"ok":true,"source":"planted","fetchedAt":"t","stale":false,"error":"","hearts":{"test.evil":999}}' >"$tmp/eng-evil/engagement.json"
cp "$tmp/eng-evil/engagement.json" "$tmp/eng-planted"
mv "$XDG_CACHE_HOME/oma_plug_sea" "$tmp/eng-real"
ln -s "$tmp/eng-evil" "$XDG_CACHE_HOME/oma_plug_sea"
"$eng" refresh >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and (.hearts|length)==0 and (.error|contains("Cache directory unavailable"))' 'symlinked engagement cache refused, planted hearts not surfaced'
cmp "$tmp/eng-planted" "$tmp/eng-evil/engagement.json"
"$eng" cached >"$tmp/out"
assert "$tmp/out" '.ok==false and .stale and (.hearts|length)==0 and (.error|contains("Cache directory unavailable"))' 'cached with unsafe dir returns empty stub'
rm "$XDG_CACHE_HOME/oma_plug_sea"; mv "$tmp/eng-real" "$XDG_CACHE_HOME/oma_plug_sea"
mv "$XDG_STATE_HOME/oma_plug_sea" "$tmp/hearts-real"
ln -s "$tmp/hearts-evil" "$XDG_STATE_HOME/oma_plug_sea"
"$eng" hearts-state >"$tmp/out"
assert "$tmp/out" '.ok==false and (.error|contains("Hearts state unavailable"))' 'symlinked hearts state refused'
: >"$TEST_ROOT/conditions"
"$eng" heart evil.id >"$tmp/out"
assert "$tmp/out" '.ok==false and .already==false and (.error|contains("Hearts state unavailable"))' 'heart with unsafe state not sent'
[[ ! -s "$TEST_ROOT/conditions" && ! -e "$tmp/hearts-evil" ]] || { echo 'FAIL: unsafe-state heart touched network or disk' >&2; exit 1; }
pass=$((pass+1))
rm "$XDG_STATE_HOME/oma_plug_sea"; mv "$tmp/hearts-real" "$XDG_STATE_HOME/oma_plug_sea"
exec 7>"$XDG_CACHE_HOME/oma_plug_sea/engagement.lock"
flock -n 7
"$eng" refresh >"$tmp/out"
assert "$tmp/out" '.stale and (.error|contains("Another"))' 'concurrent engagement refresh retains data'
flock -u 7

echo "PASS: $pass backend behavior/security assertions"
