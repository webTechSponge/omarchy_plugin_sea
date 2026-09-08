#!/usr/bin/env bash
# Offline launch-boundary checks only; never run a real agent, terminal or Omarchy action.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export TEST_ROOT="$tmp" HOME="$tmp/home"
mkdir -p "$tmp/mock" "$HOME"
export PATH="$tmp/mock:$PATH"
export TEST_DEFAULT_AGENT=codex
helper="$ROOT/bin/oma-plug-sea-review"
cat >"$tmp/mock/omarchy" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'default agent')
    [[ ${TEST_DEFAULT_FAIL:-0} == 0 ]] || exit 1
    printf '%s\n' "$TEST_DEFAULT_AGENT"
    ;;
  *)
    [[ $# == 9 && $1 == launch && $2 == tui && $3 == --app-id=org.omarchy.plugin-sea-review && $5 == session ]] || { echo 'Forbidden Omarchy invocation' >&2; exit 99; }
    printf 'terminal\n' >>"$TEST_ROOT/launches"
    printf 'Terminal launcher diagnostic\n'
    [[ ${TEST_TERMINAL_FAIL:-0} == 0 ]] || exit 1
    # Real terminal launchers can return before the session starts.
    shift 3
    printf '%s\0' "$@" >"$TEST_ROOT/terminal-command"
    ;;
esac
MOCK
cat >"$tmp/mock/codex" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'codex\n' >>"$TEST_ROOT/launches"
jq -n --arg cwd "$PWD" --arg mode "$(stat -c '%a' "$PWD")" --args '{cwd:$cwd,mode:$mode,args:$ARGS.positional}' -- "$@" >"$TEST_ROOT/codex.json"
[[ ${TEST_CODEX_FAIL:-0} == 0 ]] || exit 7
MOCK
# Presence only: invoking this directly instead of the supported dispatch is forbidden.
cat >"$tmp/mock/omarchy-launch-tui" <<'MOCK'
#!/usr/bin/env bash
exit 99
MOCK
chmod +x "$tmp/mock/omarchy" "$tmp/mock/codex" "$tmp/mock/omarchy-launch-tui"
assert() { jq -e "$2" "$1" >/dev/null || { echo "FAIL: $3" >&2; cat "$1" >&2; exit 1; }; }
"$helper" capabilities >"$tmp/result"
run_session() {
  local -a command
  mapfile -d '' -t command <"$tmp/terminal-command"
  "${command[@]}" >"$tmp/terminal-output" 2>&1
}
assert "$tmp/result" '.ok and .available and .agent=="codex"' 'configured Codex can be reviewed without launching it'
[[ ! -e $tmp/launches ]]
for agent in '' unsupported; do
  TEST_DEFAULT_AGENT="$agent" "$helper" capabilities >"$tmp/result"
  assert "$tmp/result" '.ok==false and .available==false' 'missing/unsupported defaults remain unavailable'
  TEST_DEFAULT_AGENT="$agent" "$helper" launch test.plugin https://github.com/test/plugin codex --consent-advisory-review >"$tmp/result"
  assert "$tmp/result" '.ok==false' 'default changes cannot silently select another agent'
done
TEST_DEFAULT_FAIL=1 "$helper" capabilities >"$tmp/result"
assert "$tmp/result" '.ok==false and .available==false' 'default-resolution failure stays unavailable'
"$helper" launch test.plugin https://github.com/test/plugin codex >"$tmp/result"
assert "$tmp/result" '.ok==false' 'launch requires explicit consent'
for source in 'https://github.com.evil/test/plugin' 'https://github.com/test/..' 'https://github.com/test/plugin;touch injected' 'file:///tmp/plugin'; do
  "$helper" launch test.plugin "$source" codex --consent-advisory-review >"$tmp/result"
  assert "$tmp/result" '.ok==false' 'unsupported source cannot reach the agent or terminal'
done
[[ ! -e $tmp/launches ]]
"$helper" launch test.plugin https://github.com/test/plugin codex --consent-advisory-review >"$tmp/result" 2>"$tmp/errors"
assert "$tmp/result" '.ok' 'consented review requests a terminal'
[[ ! -e $tmp/codex.json ]]
run_session
assert "$tmp/codex.json" '
  .mode=="700" and (.cwd|startswith("/tmp/oma-plug-sea-review.")) and
  .args[0:8]==["--cd",.cwd,"--sandbox","read-only","--ask-for-approval","never","--search","--"] and
  (.args|length)==9 and (.args[8]|contains("Repository: https://github.com/test/plugin"))
' 'agent receives read-only/no-escalation options and one prompt, without a model/provider override'
[[ ! -e $(jq -r .cwd "$tmp/codex.json") ]]
# A changed default after a successful terminal request still prevents execution.
rm "$tmp/codex.json"
if TEST_DEFAULT_AGENT=unsupported run_session; then
  echo 'FAIL: changed default started a review session' >&2; exit 1
fi
[[ ! -e $tmp/codex.json ]]
TEST_TERMINAL_FAIL=1 "$helper" launch test.plugin https://github.com/test/plugin codex --consent-advisory-review >"$tmp/result"
assert "$tmp/result" '.ok==false' 'terminal failure does not report successful launch'
[[ ! -e $tmp/codex.json ]]
# A failed read-only session must not retry with fewer restrictions or another model.
: >"$tmp/launches"
if TEST_CODEX_FAIL=1 run_session; then
  echo 'FAIL: failed agent was reported as a successful session' >&2; exit 1
fi
[[ $(wc -l <"$tmp/launches") == 1 && ! -e $(jq -r .cwd "$tmp/codex.json") ]]
printf 'PASS: advisory default-agent resolution, consent/source rejection, read-only launch, default-change race, failures and cleanup (offline doubles only).\n'
