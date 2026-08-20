# awesome-crush

A collection of self-playing ASCII games written in [Crush](https://github.com/nixpt/crush-ast),
each authored by a different LLM given the same minimal prompt — **"can you learn crush?"**,
pointed at `crush-ast`, nothing else — with the freedom to explore, propose what to build, and
build it.

## Why this exists

This started as a real-world comparison test: three different models (one external base model,
one external base model's own fine-tune, one different architecture entirely) hit the same
unfamiliar, still-evolving language with zero task spec, and each produced a working, self-playing
game. Rather than let those artifacts scatter across `crush-ast`'s own `examples/` directory (where
they now also live), this repo collects them side by side with the story of how each was built.

## The games

| Game | Model | State encoding | Notes |
|---|---|---|---|
| [`games/pong.crush`](games/pong.crush) | Ornith-1.5-35B-A3B (MoE) | Many scalar args threaded through recursion | v1→v2 iteration: found and self-fixed two real rendering bugs (a ball-on-column-priority bug that hid whatever wall/paddle/center-line shared its column) |
| [`games/tictactoe.crush`](games/tictactoe.crush) | foreman-v2 (Qwen3.8-27B fine-tune) | Board as a single base-3 integer | Clean on first try; found the trailing-return codegen bug via the repo's own `dejavue` memory and cited it |
| [`games/lights_out.crush`](games/lights_out.crush) | qwen38-base (base Qwen3.8-27B) | Board as a 25-bit bitfield integer | Clean on first try; extended tictactoe's integer-encoding trick to a bitfield; the only one of the three that proactively ran the full project conformance suite (874 tests) before declaring done |

All three are self-playing (no interactive input — Crush currently has no keyboard/stdin), all
three thread their entire game state through recursion-as-arguments rather than mutable arrays
(a real language constraint, not a stylistic choice — see below), and all three run to a
deterministic, verifiable conclusion.

## Real language constraints every model had to work around

Discovered independently, converged on the same answers:

- **No mutable array index-assignment, no chainable `.push()`.** All persistent per-tick state —
  ball position, board contents, scores, RNG seed — has to be passed as plain function arguments
  and threaded through recursive self-calls. Two different encoding strategies emerged: many
  separate scalar arguments (pong), or packing the whole board into a single integer via a
  positional radix (base-3 for tic-tac-toe's 3 cell states, a 25-bit field for Lights Out's 2).
- **No numeric RNG.** Every game that needs "randomness" hand-rolls a seeded linear congruential
  generator, making every run fully deterministic and reproducible.
- **No interactive stdin, no sleep.** Nothing here takes keyboard input — every game plays itself
  against itself (or, for Lights Out, against its own solver).
- **A real compiler bug, found chasing pong.crush's first version**: a function whose body's last
  statement is `if { return; } else { <call>; }` — with nothing after — compiles to bytecode
  missing a terminator, and the VM crashes at runtime with `truncated instruction at N`. The
  one-line fix is a trailing `return;` after the if/else. Filed in `crush-ast`'s own project memory
  (`dejavue`); tictactoe.crush and lights_out.crush both found it there and worked with it instead
  of hitting it blind.

## Running a game

Each game needs `crush-ast`'s own compiler/runtime (`crushc` + `crush-run`):

```bash
cd crush-ast
cargo build --release -p crush-lang-sdk --bin crushc --bin crush-run
BIN=./target/release   # or wherever your cargo target dir puts release binaries

$BIN/crushc /path/to/awesome-crush/games/pong.crush -o /tmp/pong.cvm1
$BIN/crush-run run /tmp/pong.cvm1 --cap io.print --cap str.concat --max-steps 50000000
```

The `--max-steps` bump matters — these are real, non-trivial programs (pong.crush needs well over
the VM's 1,000,000-instruction default once a board renders every frame), and the default budget
is tuned for much smaller test fixtures.

## What this repo is not

Not a benchmark, not a rigorous eval — one run each, n=1 per model, no statistical claims. It's a
real, reproducible artifact of what happened when three models met the same unfamiliar language
with the same minimal nudge. Take the comparison table as a genuine data point, not a verdict.
