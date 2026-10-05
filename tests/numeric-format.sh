#!/usr/bin/env bash
# Compare discovery identity matching with installed registry keys. Node is a
# test-only registry VM; manifests and inert entrypoints stay in isolated HOME.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
platform=${OMARCHY_PATH:-/usr/share/omarchy}
node=$(command -v node)
[[ -f $platform/shell/services/PluginRegistry.qml ]] || { echo 'Installed Omarchy registry required' >&2; exit 1; }
# Use native jq, not the tool shell builtin/jaq or a fixture replacement.
export PATH=/usr/bin:/bin LC_ALL=C
source "$root/lib/plugin-discovery.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_CACHE_HOME="$tmp/cache" XDG_STATE_HOME="$tmp/state"
plugins="$HOME/.config/omarchy/plugins"
mkdir -p "$plugins/numeric"
printf '{}' > "$HOME/.config/omarchy/shell.json"
printf 'INERT NUMERIC FIXTURE\n' > "$plugins/numeric/Fixture.qml"
passed=0
while IFS='|' read -r literal distinct; do
  [[ -n $literal ]] || continue
  # Preserve the original decimal digits until registry parsing and discovery.
  # Native Qt must accept each manifest and agree with the Node registry VM.
  printf '{"schemaVersion":1,"id":%s,"name":"Numeric fixture","version":"1.0.0","kinds":["panel"],"entryPoints":{"panel":"Fixture.qml"}}\n' "$literal" > "$plugins/numeric/manifest.json"
  "$node" "$root/tests/registry-selection.cjs" "$tmp" "$platform" rescan
  key=$(jq -er --arg source "$plugins/numeric" 'to_entries[] | select(.value.__sourceDir==$source) | .key' "$tmp/registry.json")
  jq -nc --rawfile literal "$plugins/numeric/manifest.json" --arg identity "$key" \
    '{literal:$literal,identity:$identity}' >> "$tmp/native-identities.jsonl"
  sea_unique_source "$plugins" "$key" "$plugins/numeric" || { printf 'Discovery disagrees with registry for %s -> %s\n' "$literal" "$key" >&2; exit 1; }
  [[ -z $(sea_candidates_for_id "$plugins" "$distinct") ]] || { printf 'Distinct spelling %s conflated with registry key %s\n' "$distinct" "$key" >&2; exit 1; }
  # Exact identity alone cannot authorize a different source directory.
  raw=$(sea_raw_candidates "$plugins")
  if sea_unique_candidates "$key" "$plugins/zz-string" <<<"$raw"; then
    printf 'Wrong expected source accepted for %s\n' "$literal" >&2; exit 1
  fi
  # A genuine string/numeric collision must still remain visible before the
  # registry deduplicates it to the later string manifest.
  mkdir -p "$plugins/zz-string"
  jq --arg id "$key" '.id=$id' "$plugins/numeric/manifest.json" > "$plugins/zz-string/manifest.json"
  printf 'INERT STRING FIXTURE\n' > "$plugins/zz-string/Fixture.qml"
  "$node" "$root/tests/registry-selection.cjs" "$tmp" "$platform" rescan
  selected=$("$node" "$root/tests/registry-selection.cjs" "$tmp" "$platform" source "$key")
  jq -e --arg source "$plugins/zz-string" '.ok and .sourceDir==$source' <<<"$selected" >/dev/null
  candidates=$(sea_candidates_for_id "$plugins" "$key")
  jq -se 'length==2' <<<"$candidates" >/dev/null
  if sea_unique_source "$plugins" "$key" "$plugins/numeric"; then
    printf 'Genuine collision accepted for %s\n' "$literal" >&2; exit 1
  fi
  rm -rf -- "$plugins/zz-string"
  ((passed+=1))
done <<'CASES'
1000|1e3
1|01
1e-7|1e-07
1e-6|1e-6
1e20|1e+20
1e21|1000000000000000000000
1e23|9.999999999999999e+22
-1e-6|-1e-6
-1e21|-1000000000000000000000
0|-0
-0|0.0
9007199254740993|9007199254740993
1000000000000000128|1000000000000000128
5e-324|5e-0324
5.0000000000000000001e-324|5.0000000000000000001e-324
-5.0000000000000000001e-324|-5.0000000000000000001e-324
[[[5.0000000000000000001e-324]]]|5.0000000000000000001e-324
[[[1000]]]|1e3
[[[9007199254740993]]]|9007199254740993
1.00000000000000011102230246251565404236316680908203125|1.0000000000000002
1.00000000000000011102230246251565404236316680908203126|1
0.999999999999999944488848768742172978818416595458984375|0.9999999999999999
0.999999999999999944488848768742172978818416595458984374|1
1.00000000000000033306690738754696212708950042724609375|1.0000000000000002
-1.00000000000000011102230246251565404236316680908203126|-1
-0.999999999999999944488848768742172978818416595458984374|-1
2.470328229206232720882843964341106861825300e-324|0
-2.470328229206232720882843964341106861825300e-324|0
1.797693134862315807937289714053034150799340e308|Infinity
CASES
jq -sc . "$tmp/native-identities.jsonl" > "$tmp/native-identities.json"
env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  QML_XHR_ALLOW_FILE_READ=1 QT_LOGGING_RULES='qml.debug=true' \
  timeout 15 "${QML6_BIN:-/usr/lib/qt6/bin/qml}" \
  "$root/tests/NumericIdentityTest.qml" -- "file://$tmp/native-identities.json"
[[ ! -e $tmp/enabled-content ]] || { echo 'Numeric fixture unexpectedly activated' >&2; exit 1; }
printf 'PASS: %s numeric identity cases against installed registry; matching collisions retained\n' "$passed"
