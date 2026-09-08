#!/usr/bin/env bash
# Exercise the real installed Git add/validate/catalog path, entirely in temp HOME.
# The only Git commit is a disposable local fixture; the project is never committed.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
platform=${OMARCHY_PATH:-/usr/share/omarchy}
[[ -x $platform/bin/omarchy && -x $platform/bin/omarchy-plugin-add && -x $platform/bin/omarchy-plugin-validate && -x $platform/bin/omarchy-plugin-catalog ]] || {
  echo 'Installed Omarchy Git plugin CLI required for standard installation regression.' >&2; exit 1;
}
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
source_repo=$tmp/source
isolated_home=$tmp/home
mock_bin=$tmp/mock
mkdir -p "$source_repo" "$isolated_home" "$mock_bin" "$tmp/empty-template"
# Install the whole distributable tree, not a runtime allowlist that hides unsafe
# repository extras. Include untracked additions, omit deletions and local ignores.
git -C "$root" ls-files --cached --others --exclude-standard -z > "$tmp/source-files"
while IFS= read -r -d '' file; do
  [[ -e $root/$file || -L $root/$file ]] || continue
  mkdir -p -- "$source_repo/$(dirname -- "$file")"
  cp -a -- "$root/$file" "$source_repo/$file"
done < "$tmp/source-files"
[[ ! -e $source_repo/PROMPT.md ]] || { echo 'Local execution brief leaked into source fixture.' >&2; exit 1; }
[[ ! -e $source_repo/lib/preview-decode ]] || { echo 'Generated decoder leaked into source fixture.' >&2; exit 1; }
cat > "$mock_bin/omarchy-shell" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 && $1 == shell && ( $2 == rescanPlugins || $2 == ping ) ]] || {
  echo 'Unexpected shell IPC in disabled Git install.' >&2; exit 97;
}
printf '%s\n' "$*" >> "$HOME/shell-calls"
[[ $2 != ping ]] || echo ok
MOCK
cat > "$mock_bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'fetch\n' >> "$HOME/preview-fetches"
while (( $# )); do
  if [[ $1 == -o && $# -ge 2 ]]; then cp -- "$TEST_PREVIEW_INPUT" "$2"; exit 0; fi
  shift
done
exit 98
MOCK
chmod +x "$mock_bin/omarchy-shell" "$mock_bin/curl"
run_isolated() {
  env -i HOME="$isolated_home" PATH="$mock_bin:$platform/bin:/usr/bin:/bin" \
    OMARCHY_PATH="$platform" XDG_CONFIG_HOME="$isolated_home/.config" \
    XDG_CACHE_HOME="$isolated_home/.cache" XDG_STATE_HOME="$isolated_home/.local/state" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TEMPLATE_DIR="$tmp/empty-template" \
    TEST_PREVIEW_INPUT="$tmp/input.webp" LC_ALL=C "$@"
}
run_isolated git init -q "$source_repo"
run_isolated git -C "$source_repo" add .
run_isolated git -C "$source_repo" -c user.name='Local integration fixture' -c user.email='fixture@example.invalid' commit -qm 'Disposable standard-install fixture'
# Invoke the actual packaged add; its validate/catalog subprocesses remain real.
run_isolated "$platform/bin/omarchy" plugin add "$source_repo" --yes > "$tmp/add-output" 2>&1 || { cat "$tmp/add-output" >&2; exit 1; }
installed=$isolated_home/.config/omarchy/plugins/webtechsponge.plugin-sea
[[ -d $installed/.git && ! -e $installed/lib/preview-decode ]]
[[ -f $installed/lib/preview-decode.cpp && -x $installed/bin/oma-plug-sea-build-preview && -x $installed/scripts/build-preview ]]
entry=$(jq -r '.entryPoints.overlay' "$installed/manifest.json")
[[ $entry == PluginBrowser.qml && -f $installed/$entry ]]
run_isolated "$platform/bin/omarchy" plugin validate "$installed"
run_isolated "$platform/bin/omarchy" plugin catalog | jq -e --arg dir "$installed" 'any(.[]; .id=="webtechsponge.plugin-sea" and .sourceDir==$dir)' >/dev/null
[[ $(cat "$isolated_home/shell-calls") == 'shell rescanPlugins' ]]
[[ ! -e $isolated_home/.config/omarchy/shell.json && ! -e $isolated_home/.config/omarchy/extensions/omarchy-menu.jsonc ]]
[[ -z $(run_isolated git -C "$installed" status --porcelain) ]]
printf 'PASS: real Omarchy add clones and validates an unbuilt plugin, disabled, without config hooks\n'
run_isolated git -C "$installed" ls-files -z > "$tmp/installed-files"
while IFS= read -r -d '' file; do
  case ${file##*/} in
    AGENTS.md|AGENTS.override.md|CLAUDE.md|CLAUDE.local.md|GEMINI.md)
      printf 'Auto-loaded agent instructions leaked into installed plugin: %s\n' "$file" >&2
      exit 1
      ;;
  esac
done < "$tmp/installed-files"
printf 'PASS: installed repository excludes auto-loaded agent instruction files\n'

read -r -a qt_flags <<<"$(pkg-config --cflags --libs Qt6Gui libwebpmux libwebp)"
c++ -std=c++17 -O2 "$root/tests/preview-fixture.cpp" -o "$tmp/fixture" "${qt_flags[@]}"
"$tmp/fixture" make "$tmp/input.webp" 32 24
run_isolated "$installed/bin/oma-plug-sea-preview" https://plugins.omarchy.org/assets/img/plugins/standard-cli-fixture.webp > "$tmp/preview-result"
jq -e '.ok==true and .error==""' "$tmp/preview-result" >/dev/null || { cat "$tmp/preview-result" >&2; exit 1; }
preview=$(jq -r '.path' "$tmp/preview-result")
[[ $preview == "$isolated_home/.cache/oma_plug_sea/previews/"*.png ]]
[[ $("$tmp/fixture" inspect "$preview") == 'PNG 32x24 #285e81 255' ]]
mapfile -t decoders < <(find "$isolated_home/.cache/oma_plug_sea/decoder-builds" -type f -name preview-decode)
[[ ${#decoders[@]} == 1 && -x ${decoders[0]} && ! -e $installed/lib/preview-decode ]]
[[ -z $(run_isolated git -C "$installed" status --porcelain) ]]
[[ $(wc -l < "$isolated_home/preview-fetches") == 1 ]]
printf 'PASS: first preview after real Git add builds native decoder in XDG cache and decodes fixture\n'
