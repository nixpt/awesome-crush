# awesome-crush

A collection of self-playing ASCII games written in [Crush](https://github.com/nixpt/crush-ast),
each authored by a different LLM given the same minimal prompt — **"can you learn crush?"**,
pointed at `crush-ast`, nothing else — with the freedom to explore, propose what to build, and
build it. One entry (`game_of_life.crush`) is hand-written by Claude directly rather than
dispatched, as a fourth point of comparison.

## Why this exists

This started as a real-world comparison test: three different models (one external base model,
one external base model's own fine-tune, one different architecture entirely) hit the same
unfamiliar, still-evolving language with zero task spec, and each produced a working, self-playing
game. Rather than let those artifacts scatter across `crush-ast`'s own `examples/` directory (where
they now also live), this repo collects them side by side with the story of how each was built.

## The games

| Game | Author | State encoding | Notes |
|---|---|---|---|
| [`games/pong.crush`](games/pong.crush) | Ornith-1.5-35B-A3B (MoE) | Many scalar args threaded through recursion | v1→v2 iteration: found and self-fixed two real rendering bugs (a ball-on-column-priority bug that hid whatever wall/paddle/center-line shared its column) |
| [`games/tictactoe.crush`](games/tictactoe.crush) | foreman-v2 (Qwen3.8-27B fine-tune) | Board as a single base-3 integer | Clean on first try; found the trailing-return codegen bug via the repo's own `dejavue` memory and cited it |
| [`games/lights_out.crush`](games/lights_out.crush) | qwen38-base (base Qwen3.8-27B) | Board as a 25-bit bitfield integer | Clean on first try; extended tictactoe's integer-encoding trick to a bitfield; the only one of the three dispatched models that proactively ran the full project conformance suite (874 tests) before declaring done |
| [`games/game_of_life.crush`](games/game_of_life.crush) | Claude (hand-written, not dispatched) | Board as a 25-bit bitfield integer | Conway's Game of Life — a different category entirely (cellular automaton, not a 2-player game or a scramble-and-solve puzzle); genuinely used the manifest-level AI-native annotations (`@module`/`@decision`/`@invariant`) and found a real compiler bug doing so — see below |
| [`games/blackjack.crush`](games/blackjack.crush) | OpenCode | Scalar hand totals and deck position | A pure-Crush card game: deterministic 52-card permutation, soft-ace scoring, recursive hit/stand play, dealer resolution, and bankroll across six rounds |
| [`games/pong-deepseek.crush`](games/pong-deepseek.crush) | cece / bro (DeepSeek-v4) | Many scalar args threaded through recursion | A second, independent take on Pong (distinct from Ornith's) — two self-playing paddles with an LCG-driven hesitation model; also merged into `crush-ast`'s own `examples/crush/` |
| [`games/fifteen_puzzle.crush`](games/fifteen_puzzle.crush) | bro (DeepSeek-v4) | 15 tiles packed as base-16 nibbles in one i64, blank as a separate scalar | From the captain's own separate bro session (not one of this repo's dispatches) — that session finished the code but hung before it could commit; recovered and verified here. The most algorithmically sophisticated entry: real IDA* (iterative-deepening A*) with a Manhattan-distance heuristic, seeded-LCG scramble, packed move-path replay. Verified solving a 30-move scramble optimally in 6 moves — matching the initial heuristic estimate exactly |

All seven are self-playing (no interactive input — Crush currently has no keyboard/stdin), all
seven thread their entire game state through recursion-as-arguments rather than mutable arrays
(a real language constraint, not a stylistic choice — see below), and all seven run to a
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

## Crush's AI-native annotations — genuinely used, and one real bug found

Crush ships a manifest-level annotation system aimed specifically at making code
agent-legible — `@module { purpose, exports, invariants, related }`, `@decision { chose, over,
because, revisit-if }`, `@invariant { description, applies_to, check }`, plus a few others
(`@wip`, `@temporary`, `@errors`). `game_of_life.crush` uses three of them for real (documenting
why the board is packed into an integer instead of an array, and the invariant that keeps it in
bounds) rather than as decoration.

Verifying that surfaced a real compiler bug: **`crushc` hangs indefinitely — not an error, an
infinite loop — parsing `@decision`'s `revisit-if` field.** Isolated by bisection: `@module` alone
compiles fine, `@invariant` alone compiles fine, `@decision` with `chose`/`because`/`over[]` all
compile fine, but `@decision { revisit-if: [...] }` alone hangs with zero output. Almost certainly
the field name itself — `revisit-if` — confuses the parser, since `if` is a reserved keyword
immediately after the hyphen. This is very likely the actual root cause of `crush-ast`'s own
`examples/crush/ai_agent_ops.crush`, which is marked `// expect-error: TIMEOUT` and does use
`revisit-if` — previously explainable by that file's unimplemented `semantic_switch`/`ai_synthesize`
runtime calls, but the hang happens at parse time, before either of those would ever run.
`game_of_life.crush`'s own `@decision` block deliberately omits `revisit-if`, with a comment
explaining why.

The runtime AI-expression layer (`semantic_switch`, `ai_synthesize`, `ai_semantic_match`) is a
separate, further-out concept — not attempted here, and `ai_agent_ops.crush`'s own `expect-error`
marker already signals it isn't working code yet.

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
