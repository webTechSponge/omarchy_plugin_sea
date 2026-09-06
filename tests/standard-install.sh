#!/usr/bin/env bash
# A plain source checkout must render previews without dev-install or mise setup.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'chmod -R u+w "$tmp"; rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/plugin/bin" "$tmp/plugin/lib" "$tmp/mock"
cp "$ROOT"/bin/* "$tmp/plugin/bin/"
cp "$ROOT/lib/preview-decode.cpp" "$tmp/plugin/lib/"
[[ ! -e $tmp/plugin/lib/preview-decode && ! -e $tmp/plugin/scripts && ! -e $tmp/plugin/mise.toml ]]
read -r -a qt_flags <<<"$(pkg-config --cflags --libs Qt6Gui libwebpmux libwebp)"
c++ -std=c++17 -O2 "$ROOT/tests/preview-fixture.cpp" -o "$tmp/fixture" "${qt_flags[@]}"
"$tmp/fixture" make "$tmp/input.webp" 32 24
export TEST_STANDARD_ROOT="$tmp" XDG_CACHE_HOME="$tmp/cache"
export TEST_STANDARD_CXX="$(command -v g++)" TEST_STANDARD_PKGCONFIG="$(command -v pkg-config)"
cat >"$tmp/mock/g++" <<'MOCK'
#!/usr/bin/env bash
if [[ " $* " == *' -o '* ]]; then
  printf 'compile\n' >>"$TEST_STANDARD_ROOT/compiles"
  if [[ ${TEST_STANDARD_COMPILE_FAIL:-0} == 1 ]]; then
    while (( $# )); do
      if [[ $1 == -o ]]; then printf 'partial compiler output\n' >"$2"; chmod +x "$2"; break; fi
      shift
    done
    echo 'Simulated compiler failure after writing partial output' >&2
    exit 42
  fi
fi
exec "$TEST_STANDARD_CXX" "$@"
MOCK
cat >"$tmp/mock/pkg-config" <<'MOCK'
#!/usr/bin/env bash
[[ ${TEST_STANDARD_MISSING_QT:-0} == 0 ]] || exit 1
exec "$TEST_STANDARD_PKGCONFIG" "$@"
MOCK
cat >"$tmp/mock/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'fetch\n' >>"$TEST_STANDARD_ROOT/fetches"
[[ ${TEST_STANDARD_NETWORK_FAIL:-0} == 0 ]] || exit 7
while (( $# )); do
 if [[ $1 == -o ]]; then cp "$TEST_STANDARD_ROOT/input.webp" "$2"; exit; fi
 shift
done
exit 2
MOCK
cat >"$tmp/mock/mise" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected mise invocation\n' >>"$TEST_STANDARD_ROOT/mise-invoked"
exit 99
MOCK
chmod +x "$tmp/mock/"*
export PATH="$tmp/mock:$PATH"
# Compilation belongs in the private cache, never the plugin checkout.
chmod -R a-w "$tmp/plugin"
helper="$tmp/plugin/bin/oma-plug-sea-preview"
url=https://plugins.omarchy.org/assets/img/plugins/standard-install.webp
"$helper" https://evil.example/preview.webp >"$tmp/rejected"
jq -e '.ok==false and .path==""' "$tmp/rejected" >/dev/null
[[ ! -e $tmp/compiles && ! -e $tmp/fetches ]]
"$helper" "$url" >"$tmp/first" &
pid=$!
"$helper" https://plugins.omarchy.org/assets/img/plugins/standard-other.webp >"$tmp/second"
wait "$pid"
jq -e '.ok and .error==""' "$tmp/first" >/dev/null
jq -e '.ok and .error==""' "$tmp/second" >/dev/null
[[ $("$tmp/fixture" inspect "$(jq -r '.path' "$tmp/first")") == 'PNG 32x24 #285e81 255' ]]
[[ $(wc -l <"$tmp/compiles") == 1 ]]
[[ $(wc -l <"$tmp/fetches") == 2 ]]
TEST_STANDARD_NETWORK_FAIL=1 "$helper" "$url" >"$tmp/cached"
jq -e '.ok' "$tmp/cached" >/dev/null
[[ $(jq -r '.path' "$tmp/first") == "$(jq -r '.path' "$tmp/cached")" ]]
"$helper" https://plugins.omarchy.org/assets/img/plugins/standard-third.webp >"$tmp/reuse"
jq -e '.ok' "$tmp/reuse" >/dev/null
[[ $(wc -l <"$tmp/compiles") == 1 ]]
[[ $(wc -l <"$tmp/fetches") == 3 ]]
[[ ! -e $tmp/plugin/lib/preview-decode && ! -e $tmp/plugin/lib/preview-decode.build-id ]]
# A fresh user cache with unavailable Qt build files produces recovery guidance.
TEST_STANDARD_MISSING_QT=1 XDG_CACHE_HOME="$tmp/missing-cache" "$helper" "$url" >"$tmp/missing"
jq -e '.ok==false and .path=="" and (.error|test("qt6-base|Qt6")) and (.error|test("install|Install|omarchy pkg add"))' "$tmp/missing" >/dev/null
[[ $(wc -l <"$tmp/compiles") == 1 ]]
# An update to the bundled trusted source invalidates the binary cache key.
old_decoder=$("$tmp/plugin/bin/oma-plug-sea-build-preview")
chmod u+w "$tmp/plugin/lib/preview-decode.cpp"
printf '\n// Source update cache invalidation fixture.\n' >>"$tmp/plugin/lib/preview-decode.cpp"
chmod a-w "$tmp/plugin/lib/preview-decode.cpp"
"$helper" https://plugins.omarchy.org/assets/img/plugins/standard-updated.webp >"$tmp/updated"
jq -e '.ok' "$tmp/updated" >/dev/null
new_decoder=$("$tmp/plugin/bin/oma-plug-sea-build-preview")
[[ $old_decoder != "$new_decoder" && -x $old_decoder && -x $new_decoder ]]
[[ $(wc -l <"$tmp/compiles") == 2 ]]
# A compiler that leaves partial output must publish nothing; retry can recover.
TEST_STANDARD_COMPILE_FAIL=1 XDG_CACHE_HOME="$tmp/failure-cache" "$helper" "$url" >"$tmp/failed"
jq -e '.ok==false and .path=="" and (.error|contains("compilation failed")) and (.error|contains("retry"))' "$tmp/failed" >/dev/null
[[ $(wc -l <"$tmp/compiles") == 3 ]]
[[ $(find "$tmp/failure-cache" -type f -executable | wc -l) == 0 ]]
[[ $(find "$tmp/failure-cache" -name '*.build-id' -o -name '.preview-decode-build.*' | wc -l) == 0 ]]
XDG_CACHE_HOME="$tmp/failure-cache" "$helper" "$url" >"$tmp/retry"
jq -e '.ok' "$tmp/retry" >/dev/null
[[ $(wc -l <"$tmp/compiles") == 4 ]]
[[ $("$tmp/fixture" inspect "$(jq -r '.path' "$tmp/retry")") == 'PNG 32x24 #285e81 255' ]]
[[ ! -e $tmp/mise-invoked ]]
echo 'PASS: plain install lazy build/concurrency/cache, source invalidation, failed-build cleanup/retry, dependency guidance, no mise'
