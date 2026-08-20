# brainfuck.crush — a Brainfuck interpreter written in Crush

The second entry in this repo that is **not a game**, alongside
[`../forth/forth.crush`](../forth/forth.crush). Where Forth is a stack language,
this one hosts the canonical "can your language run another language?" test:
[Brainfuck](https://en.wikipedia.org/wiki/Brainfuck) — eight instructions, a
byte tape, a pointer, and bracket-matched loops.

## How it works

- The program is a single string; `prog[i]` (string indexing yields a
  one-character string) walks it one instruction at a time.
- The tape is a fixed 32-cell integer array mutated with indexed assignment
  (`tape[ptr] = v`) — the same real-array machinery `forth.crush` uses, and
  what every game in this repo predates or missed.
- `[` and `]` are matched by one generalized `scan()` helper (a
  nesting-depth counter) — no precompiled jump table. It is byte-for-byte the
  same function `forth.crush` uses for `if/else/then`; it is copy-pasted rather
  than `import`ed because the standalone `crushc`/`crush-run` toolchain has no
  working cross-file import.
- **Output is the hard part.** Crush has no `chr()`/`ord()`, and the standalone
  `crush-run` binary has no `conv.*` (that lives behind the unbuilt `stdlib`
  feature). A byte is turned into a character by indexing a 95-character string
  of printable ASCII (codes 32..126) at `value - 32`; newline (10) is
  special-cased. This is the entry's one novel trick.

## Running it

```bash
cd crush-ast
BIN=./target/release   # or wherever your cargo target dir puts release binaries

$BIN/crushc /path/to/awesome-crush/brainfuck/brainfuck.crush -o /tmp/bf.cvm1
$BIN/crush-run run /tmp/bf.cvm1 \
    --cap io.print --cap arr_set --cap str.len \
    --max-steps 20000000
```

Three capabilities over the games' `io.print --cap str.concat`: `arr_set` is
indexed tape mutation, `str.len` sizes the program string.

## What it runs

`main` feeds three Brainfuck programs through the interpreter, all deterministic:

| Program | Output |
|---|---|
| classic Hello World (with nested loops) | `Hello World!` |
| A–Z via a counted loop | `ABCDEFGHIJKLMNOPQRSTUVWXYZ` |
| 0–9 via a counted loop | `0123456789` |

## Scope boundaries (honest)

- **Fixed 32-cell tape**, pointer clamped at the edges (Brainfuck's tape is
  notionally infinite; Crush arrays cannot grow from source).
- **`, ` (input) is a no-op** — Crush has no stdin.
- Cell wrapping is modelled (`+`/`-` wrap at 255/0) but none of the three
  programs exercise it.
