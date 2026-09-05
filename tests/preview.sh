#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CACHE_HOME="$tmp/cache" TEST_PREVIEW_ROOT="$tmp"
mkdir -p "$tmp/mock"
magick -size 32x24 xc:'#285e81' "$tmp/input.webp"
cat >"$tmp/mock/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'fetch\n' >>"$TEST_PREVIEW_ROOT/fetches"
[[ ${TEST_PREVIEW_FAIL:-0} == 0 ]] || { echo 'simulated failure' >&2; exit 7; }
while (( $# )); do
 if [[ $1 == -o ]]; then cp "$TEST_PREVIEW_ROOT/input.webp" "$2"; exit; fi
 shift
done
exit 2
MOCK
chmod +x "$tmp/mock/curl"
export PATH="$tmp/mock:$PATH"
helper="$ROOT/bin/oma-plug-sea-preview"
url=https://plugins.omarchy.org/assets/img/plugins/test-preview.webp
"$helper" "$url" >"$tmp/out"
jq -e '.ok and .error==""' "$tmp/out" >/dev/null
image_path=$(jq -r '.path' "$tmp/out")
[[ $(magick identify -format '%m %wx%h' "$image_path") == 'PNG 32x24' ]]
TEST_PREVIEW_FAIL=1 "$helper" "$url" >"$tmp/out"
jq -e '.ok' "$tmp/out" >/dev/null
[[ $(wc -l <"$tmp/fetches") == 1 ]]
for bad in 'file:///etc/passwd' 'https://example.com/a.webp' 'https://plugins.omarchy.org/assets/img/plugins/../x.webp' 'https://plugins.omarchy.org/assets/img/plugins/x.webp?cmd=oops' 'https://plugins.omarchy.org/assets/img/plugins/x.webp;touch /tmp/unsafe'; do
 "$helper" "$bad" >"$tmp/out"
 jq -e '.ok==false and .path==""' "$tmp/out" >/dev/null
done
[[ $(wc -l <"$tmp/fetches") == 1 ]]
TEST_PREVIEW_FAIL=1 "$helper" https://plugins.omarchy.org/assets/img/plugins/missing.webp >"$tmp/out"
jq -e '.ok==false and (.error|contains("download failed"))' "$tmp/out" >/dev/null
printf 'push graphic-context\nviewbox 0 0 100 100\nimage over 0,0 0,0 "label:unexpected"\npop graphic-context\n' >"$tmp/input.webp"
"$helper" https://plugins.omarchy.org/assets/img/plugins/hostile.webp >"$tmp/out"
jq -e '.ok==false and (.error|contains("conversion failed"))' "$tmp/out" >/dev/null
magick -size 1800x1300 xc:blue "$tmp/input.webp"
"$helper" https://plugins.omarchy.org/assets/img/plugins/large.webp >"$tmp/first" &
pid=$!
"$helper" https://plugins.omarchy.org/assets/img/plugins/large.webp >"$tmp/second"
wait "$pid"
jq -e '.ok' "$tmp/first" >/dev/null
jq -e '.ok' "$tmp/second" >/dev/null
[[ $(jq -r '.path' "$tmp/first") == "$(jq -r '.path' "$tmp/second")" ]]
[[ $(magick identify -format '%w' "$(jq -r '.path' "$tmp/first")") == 1200 ]]
# One initial image, failed download, malformed image, one concurrent conversion.
[[ $(wc -l <"$tmp/fetches") == 4 ]]
[[ $(find "$XDG_CACHE_HOME" -name '.preview.*' | wc -l) == 0 ]]
echo 'PASS: preview decoding, caching, URL boundary, malformed input, scaling and concurrency'
