#!/usr/bin/env bash
# Exercise normalized catalog values in the actual production QML component,
# including old cached values that no longer pass current normalization.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/components" "$tmp/bin" "$tmp/lib" "$tmp/mock"
cp "$ROOT/components/PreviewImage.qml" "$tmp/components/"
cp "$ROOT/bin/oma-plug-sea-preview" "$tmp/bin/"
cp "$ROOT/lib/preview-decode" "$tmp/lib/"
read -r -a qt_flags <<<"$(pkg-config --cflags --libs Qt6Gui libwebpmux libwebp)"
c++ -std=c++17 -O2 "$ROOT/tests/preview-fixture.cpp" -o "$tmp/fixture" "${qt_flags[@]}"
"$tmp/fixture" make "$tmp/input.webp" 32 24
export TEST_PREVIEW_ROOT="$tmp" XDG_CACHE_HOME="$tmp/cache"
cat >"$tmp/mock/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'fetch\n' >>"$TEST_PREVIEW_ROOT/fetches"
while (( $# )); do
 if [[ $1 == -o ]]; then cp "$TEST_PREVIEW_ROOT/input.webp" "$2"; exit; fi
 shift
done
exit 2
MOCK
chmod +x "$tmp/mock/curl"
export PATH="$tmp/mock:$PATH"
cat >"$tmp/catalog.json" <<'JSON'
{"plugins":[
 {"id":"test.good","name":"Good","previewImage":"assets/img/plugins/good.webp","previewThumbnail":"https://plugins.omarchy.org/assets/img/plugins/thumb.webp"},
 {"id":"test.extensionless","name":"Extensionless","previewImage":"https://plugins.omarchy.org/assets/img/plugins/payload"},
 {"id":"test.png","name":"PNG","previewImage":"https://plugins.omarchy.org/assets/img/plugins/bypass.png"},
 {"id":"test.jpg","name":"JPEG","previewImage":"assets/img/plugins/bypass.jpg"},
 {"id":"test.svg","name":"SVG","previewImage":"https://evil.example/payload.svg"},
 {"id":"test.foreign","name":"Foreign","previewImage":"https://evil.example/payload.webp"},
 {"id":"test.traversal","name":"Traversal","previewImage":"assets/img/plugins/../payload.webp"},
 {"id":"test.query","name":"Query","previewImage":"https://plugins.omarchy.org/assets/img/plugins/a.webp?x=1"}
]}
JSON
jq --arg source test --arg now test -f "$ROOT/lib/normalize.jq" "$tmp/catalog.json" >"$tmp/normalized.json"
jq -e '.plugins[0].previewImage=="https://plugins.omarchy.org/assets/img/plugins/good.webp" and .plugins[0].previewThumbnail=="https://plugins.omarchy.org/assets/img/plugins/thumb.webp" and all(.plugins[1:][]; .previewImage=="")' "$tmp/normalized.json" >/dev/null
cat >"$tmp/shell.qml" <<'QML'
import QtQuick
import Quickshell
import "components"
Item {
    id: test
    property int index: 0
    property int polls: 0
QML
printf '    property var cases: ' >>"$tmp/shell.qml"
jq -cs '.[0].plugins | map({source:.previewImage, accepted:(.id=="test.good")})' "$tmp/normalized.json" >>"$tmp/shell.qml"
cat >>"$tmp/shell.qml" <<'QML'
    // Legacy caches and direct component callers cannot bypass the downloader.
    property var legacy: [
        {source:"https://plugins.omarchy.org/assets/img/plugins/payload",accepted:false},
        {source:"https://evil.example/payload",accepted:false},
        {source:"https://plugins.omarchy.org/assets/img/plugins/bypass.png",accepted:false},
        {source:"https://evil.example/payload.jpg",accepted:false},
        {source:"https://evil.example/payload.webp",accepted:false},
        {source:"https://plugins.omarchy.org/assets/img/plugins/../payload.webp",accepted:false},
        {source:"file:///etc/passwd",accepted:false}
    ]
    PreviewImage { id: preview; width: 100; height: 100; requestedWidth: 32 }
    function fail(message) { console.error("BOUNDARY FAIL: " + message); Qt.quit(); }
    Component.onCompleted: {
        cases = cases.concat(legacy);
        preview.source = cases[0].source;
    }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            var current = test.cases[test.index];
            if (preview.imageSource && preview.imageSource.indexOf("file://") !== 0) { test.fail("Remote URL reached native Image: " + preview.imageSource); return; }
            if (current.accepted) {
                if (preview.failed) { test.fail("Approved helper preview failed"); return; }
                if (!preview.ready) {
                    if (++test.polls > 100) test.fail("Approved helper preview timed out");
                    return;
                }
                if (preview.intrinsicWidth !== 32) { test.fail("Expected decoded fixture dimensions"); return; }
            } else if (!preview.failed || preview.ready || preview.imageSource !== "") {
                test.fail("Unsupported source entered decoder: " + current.source); return;
            }
            test.index++;
            test.polls = 0;
            if (test.index === test.cases.length) {
                console.log("PASS: actual catalog-to-QML preview boundary");
                Qt.quit();
            } else preview.source = test.cases[test.index].source;
        }
    }
}
QML
env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen timeout 15 quickshell -p "$tmp/shell.qml" >"$tmp/runtime.log" 2>&1 || { cat "$tmp/runtime.log"; exit 1; }
rg -q 'PASS: actual catalog-to-QML preview boundary' "$tmp/runtime.log" || { cat "$tmp/runtime.log"; exit 1; }
[[ $(wc -l <"$tmp/fetches") == 1 ]]
echo 'PASS: normalized and legacy catalog previews enforce actual QML downloader boundary'
