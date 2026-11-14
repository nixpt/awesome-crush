#!/usr/bin/env bash
# games/v2 checks. One "ok <name>" line per passing check; exits nonzero on any failure.
#   CRUSH_RUN  crush-run binary   (default /workspace/bin/release/crush-run)
#   FACET_DIR  dir holding facet.crush (default /workspace/projects/facet)
#   POLISH     polish script      (default /workspace/projects/polish/scripts/polish)
#   UPDATE_GOLDEN=1 rewrites the golden files instead of comparing.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRUSH_RUN="${CRUSH_RUN:-/workspace/bin/release/crush-run}"
FACET_DIR="${FACET_DIR:-/workspace/projects/facet}"
POLISH="${POLISH:-/workspace/projects/polish/scripts/polish}"
FAILS=0

ok() { echo "ok $1"; }
bad() { echo "FAIL $1: $2"; FAILS=$((FAILS + 1)); }

# run <file> <args...>: stdout of the game; stderr is left visible; sets RC.
run() {
    local f="$1"; shift
    timeout 120 "$CRUSH_RUN" run -L "$FACET_DIR" --time --max-steps 200000000 "$f" -- "$@" < /dev/null
    RC=$?
}

# capture <file> <args...>: like run, but stdout into OUT; stderr into ERR (printed on failure).
capture() {
    local f="$1"; shift
    local errf; errf="$(mktemp)"
    OUT="$(timeout 120 "$CRUSH_RUN" run -L "$FACET_DIR" --time --max-steps 200000000 "$f" -- "$@" 2> "$errf" < /dev/null)"
    RC=$?
    ERR="$(cat "$errf")"; rm -f "$errf"
}

check_game() {
    local game="$1" file="$HERE/$1/$2"; shift 2
    local -a cases=("$@")   # "name|args..."
    local c name args want

    for c in "${cases[@]}"; do
        name="${c%%|*}"; args="${c#*|}"
        want="$HERE/$game/golden/$name.out"
        # shellcheck disable=SC2086
        capture "$file" $args
        if [ "$RC" -ne 0 ]; then bad "$game golden $name" "exit $RC: $ERR"; continue; fi
        if [ "${UPDATE_GOLDEN:-0}" = 1 ]; then printf '%s\n' "$OUT" > "$want"; fi
        if [ "$OUT" = "$(cat "$want")" ]; then ok "$game golden $name"; else bad "$game golden $name" "output differs from $want"; fi
    done

    capture "$file" --help
    if [ "$RC" -eq 0 ] && [[ "$OUT" == *Usage:* ]]; then ok "$game --help exits 0"; else bad "$game --help" "rc=$RC"; fi

    capture "$file" --no-such-flag
    if [ "$RC" -eq 2 ]; then ok "$game unknown flag exits 2"; else bad "$game unknown flag" "rc=$RC"; fi
    [ -n "$ERR$OUT" ] && echo "$ERR$OUT" | head -n 1 | sed 's/^/    /'

    capture "$file" --watch --headless
    if [ "$RC" -eq 2 ] && [[ "$ERR$OUT" == *"--watch and --headless are mutually exclusive"* ]]; then
        ok "$game --watch --headless exits 2 (exclusive group)"
    else bad "$game --watch --headless" "rc=$RC: $ERR$OUT"; fi

    local a b
    args="${cases[0]#*|}"
    # shellcheck disable=SC2086
    capture "$file" $args; a="$OUT"
    # shellcheck disable=SC2086
    capture "$file" $args; b="$OUT"
    if [ -n "$a" ] && [ "$a" = "$b" ]; then ok "$game same seed, same output"; else bad "$game same seed" "outputs differ or empty"; fi

    if "$POLISH" check "$file"; then ok "$game polish check (0 errors)"; else bad "$game polish check" "errors"; fi
}

check_game game_of_life life.crush \
    "watch_seed7|--seed 7 --width 12 --height 6 --generations 5 -vv" \
    "headless_seed42|--seed 42 --headless --generations 30 -v"

check_game tictactoe tictactoe.crush \
    "watch_seed3|--seed 3 --rounds 2 --x random --o first" \
    "headless_seed9|--seed 9 --rounds 8 --x random --o minimax --headless -vv" \
    "minimax_draw|--rounds 1 --x minimax --o minimax --headless -v"

if [ "$FAILS" -ne 0 ]; then echo "FAILED: $FAILS check(s)"; exit 1; fi
echo "all checks passed"
