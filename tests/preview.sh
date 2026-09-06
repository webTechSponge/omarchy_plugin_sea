#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export XDG_CACHE_HOME="$tmp/cache" TEST_PREVIEW_ROOT="$tmp"
mkdir -p "$tmp/mock"
read -r -a qt_flags <<<"$(pkg-config --cflags --libs Qt6Gui libwebpmux libwebp)"
c++ -std=c++17 -O2 "$ROOT/tests/preview-fixture.cpp" -o "$tmp/fixture" "${qt_flags[@]}"
"$tmp/fixture" make "$tmp/input.webp" 32 24
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
cat >"$tmp/mock/magick" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected ImageMagick invocation\n' >>"$TEST_PREVIEW_ROOT/magick-invoked"
exit 99
MOCK
chmod +x "$tmp/mock/curl" "$tmp/mock/magick"
export PATH="$tmp/mock:$PATH"
helper="$ROOT/bin/oma-plug-sea-preview"
url=https://plugins.omarchy.org/assets/img/plugins/test-preview.webp
"$helper" "$url" >"$tmp/out"
jq -e '.ok and .error==""' "$tmp/out" >/dev/null
image_path=$(jq -r '.path' "$tmp/out")
[[ $("$tmp/fixture" inspect "$image_path") == 'PNG 32x24 #285e81 255' ]]
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
# Defense in depth: decoder still bounds bytes when a downloader misbehaves.
truncate -s 8388609 "$tmp/input.webp"
"$helper" https://plugins.omarchy.org/assets/img/plugins/too-many-bytes.webp >"$tmp/out"
jq -e '.ok==false and (.error|contains("conversion failed"))' "$tmp/out" >/dev/null
# Small complete RIFF files need decoder compatibility padding; incomplete ones must fail.
"$tmp/fixture" make "$tmp/input.webp" 32 24
truncate -s -1 "$tmp/input.webp"
"$helper" https://plugins.omarchy.org/assets/img/plugins/truncated.webp >"$tmp/out"
jq -e '.ok==false and (.error|contains("conversion failed"))' "$tmp/out" >/dev/null
# A PNG at a trusted .webp URL must not select another decoder.
"$tmp/fixture" make "$tmp/input.webp" 32 24 png
"$helper" https://plugins.omarchy.org/assets/img/plugins/disguised.webp >"$tmp/out"
jq -e '.ok==false and (.error|contains("conversion failed"))' "$tmp/out" >/dev/null
# Reject unreasonable dimensions even when compressed bytes are tiny.
"$tmp/fixture" make "$tmp/input.webp" 8193 2
"$helper" https://plugins.omarchy.org/assets/img/plugins/oversized.webp >"$tmp/out"
jq -e '.ok==false and (.error|contains("conversion failed"))' "$tmp/out" >/dev/null
"$tmp/fixture" make "$tmp/input.webp" 32 24 metadata
rg -a -q 'private-preview-test-metadata' "$tmp/input.webp"
"$helper" https://plugins.omarchy.org/assets/img/plugins/metadata.webp >"$tmp/out"
jq -e '.ok' "$tmp/out" >/dev/null
image_path=$(jq -r '.path' "$tmp/out")
"$tmp/fixture" inspect "$image_path" >/dev/null
! rg -a -q 'private-preview-test-metadata' "$image_path"
"$tmp/fixture" make "$tmp/input.webp" 32 24 animation
"$helper" https://plugins.omarchy.org/assets/img/plugins/animated.webp >"$tmp/out"
jq -e '.ok' "$tmp/out" >/dev/null
[[ $("$tmp/fixture" inspect "$(jq -r '.path' "$tmp/out")") == 'PNG 32x24 #285e81 255' ]]
"$tmp/fixture" make "$tmp/input.webp" 32 24 alpha
"$helper" https://plugins.omarchy.org/assets/img/plugins/alpha.webp >"$tmp/out"
jq -e '.ok' "$tmp/out" >/dev/null
[[ $("$tmp/fixture" inspect "$(jq -r '.path' "$tmp/out")") == 'PNG 32x24 #285e81 128' ]]
"$tmp/fixture" make "$tmp/input.webp" 1 8192
"$helper" https://plugins.omarchy.org/assets/img/plugins/thin.webp >"$tmp/out"
jq -e '.ok' "$tmp/out" >/dev/null
[[ $("$tmp/fixture" inspect "$(jq -r '.path' "$tmp/out")") == 'PNG 1x1200 #285e81 255' ]]
"$tmp/fixture" make "$tmp/input.webp" 1800 1300
"$helper" https://plugins.omarchy.org/assets/img/plugins/large.webp >"$tmp/first" &
pid=$!
"$helper" https://plugins.omarchy.org/assets/img/plugins/large.webp >"$tmp/second"
wait "$pid"
jq -e '.ok' "$tmp/first" >/dev/null
jq -e '.ok' "$tmp/second" >/dev/null
[[ $(jq -r '.path' "$tmp/first") == "$(jq -r '.path' "$tmp/second")" ]]
[[ $("$tmp/fixture" inspect "$(jq -r '.path' "$tmp/first")") == 'PNG 1200x867 #285e81 255' ]]
# Full-size requests preserve native pixels and never reuse the thumbnail cache.
large_url=https://plugins.omarchy.org/assets/img/plugins/large.webp
"$helper" "$large_url" original >"$tmp/original"
jq -e '.ok' "$tmp/original" >/dev/null
original_path=$(jq -r '.path' "$tmp/original")
[[ $original_path != "$(jq -r '.path' "$tmp/first")" ]]
[[ $("$tmp/fixture" inspect "$original_path") == 'PNG 1800x1300 #285e81 255' ]]
TEST_PREVIEW_FAIL=1 "$helper" "$large_url" original >"$tmp/out"
jq -e --arg path "$original_path" '.ok and .path==$path' "$tmp/out" >/dev/null
TEST_PREVIEW_FAIL=1 "$helper" "$large_url" >"$tmp/out"
[[ $("$tmp/fixture" inspect "$(jq -r '.path' "$tmp/out")") == 'PNG 1200x867 #285e81 255' ]]
for option in '' --original invalid '../original'; do
  "$helper" "$large_url" "$option" >"$tmp/out"
  jq -e '.ok==false and .path==""' "$tmp/out" >/dev/null
done
"$helper" "$large_url" original unexpected >"$tmp/out"
jq -e '.ok==false and .path==""' "$tmp/out" >/dev/null
if "$ROOT/lib/preview-decode" "$tmp/input.webp" "$tmp/invalid-option.png" --invalid 2>"$tmp/error"; then
  echo 'FAIL: decoder accepted an unknown option' >&2
  exit 1
fi
[[ ! -e $tmp/invalid-option.png ]]
# Original mode keeps dimension limits despite bypassing the thumbnail resize.
"$tmp/fixture" make "$tmp/input.webp" 8193 2
"$helper" https://plugins.omarchy.org/assets/img/plugins/oversized-original.webp original >"$tmp/out"
jq -e '.ok==false and (.error|contains("conversion failed"))' "$tmp/out" >/dev/null
# A symlinked cache directory is refused before any download or outside write.
mkdir -p "$tmp/elsewhere" "$tmp/evil-cache"
ln -s "$tmp/elsewhere" "$tmp/evil-cache/oma_plug_sea"
XDG_CACHE_HOME="$tmp/evil-cache" "$helper" "$url" >"$tmp/out"
jq -e '.ok==false and .path=="" and (.error|contains("unavailable"))' "$tmp/out" >/dev/null
[[ $(find "$tmp/elsewhere" -mindepth 1 | wc -l) == 0 ]]
# Initial, failed, malformed, byte limit, truncated, disguised, dimensions, metadata,
# animated, alpha, thin, concurrent, original, original dimension rejection.
[[ $(wc -l <"$tmp/fetches") == 14 ]]
[[ $(find "$XDG_CACHE_HOME" -name '.preview.*' | wc -l) == 0 ]]
[[ ! -e $tmp/magick-invoked ]]
echo 'PASS: preview decoding, caching, URL boundary, malformed/foreign/oversized input, metadata stripping, first frame, transparency, scaling, native-size cache separation and concurrency'
