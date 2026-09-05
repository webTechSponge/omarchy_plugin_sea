#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# Arch may put Qt 5's qml on PATH; the host uses Qt 6.
runner=${QML6_BIN:-/usr/lib/qt6/bin/qml}
[[ -x $runner ]] || { echo 'Qt 6 qml runner required (set QML6_BIN).' >&2; exit 1; }
QT_QPA_PLATFORM=offscreen QT_LOGGING_RULES='qml.debug=true' timeout 15 "$runner" "$ROOT/tests/ModelTest.qml"
echo 'PASS: 13 Qt 6 catalog model assertions'
