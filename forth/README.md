# forth.crush — a Forth interpreter written in Crush

The first entry in this repo that is **not a game**. Instead of rendering a
board and playing itself, this one *interprets other programs*: it is a small
but real [Forth](https://en.wikipedia.org/wiki/Forth_(programming_language))
runtime — a second stack language hosted inside Crush's own stack-based VM.

It is also the only entry that uses Crush's **array and string capabilities**
rather than packing all state into one integer:

- `str.split` turns the Forth source into an array of tokens (and string
  indexing `s[i]` reads them one character at a time),
- a fixed-size integer array + a depth counter is the Forth data stack,
  mutated with indexed assignment (`stk[dsp] = v`),
- a second fixed array is the return stack for loop frames.

Every game in `../games/` predates (or independently missed) `crush-ast`'s
CRUSH-7 array-mutation fix and so threads state through recursion-as-arguments
or packs boards into a single `i64`. This entry reads the *current* toolchain
and uses real arrays, `str.split`, and `str.replace`.

## The wordset

Numbers (integers, with a leading `-` for negatives), `+ - * / mod`,
`dup drop swap over rot`, `= <> < >`, output (`. .s cr` and single-word
string literals `."word"`), counted loops (`do ... loop` with `i`), and
conditionals (`if ... else ... then`, nested).

## Running it

```bash
cd crush-ast
BIN=./target/release   # or wherever your cargo target dir puts release binaries

$BIN/crushc /path/to/awesome-crush/forth/forth.crush -o /tmp/forth.cvm1
$BIN/crush-run run /tmp/forth.cvm1 \
    --cap io.print --cap arr_set --cap str.split --cap str.replace --cap str.len \
    --max-steps 20000000
```

The four extra capabilities (over the games' `io.print --cap str.concat`) are
the whole point: `arr_set` is indexed array mutation, `str.split` is the
tokenizer, `str.replace` strips `."` from string literals, and `str.len` sizes
them.

## What it runs

`main` feeds five Forth programs through the interpreter, all deterministic:

| Program | Source | Output |
|---|---|---|
| stack arithmetic | `3 4 + dup * .s .` | `stack(1): 49` then `49` |
| fibonacci (10 terms) | `0 1 10 0 do dup . swap over + loop` | `1 1 2 3 5 8 13 21 34 55` |
| 7! factorial | `1 8 1 do i * loop .` | `5040` |
| FizzBuzz (1..15) | nested `if/else/then` | `1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz` |
| wordset smoke test | `/ - < <> rot >` and `-5` | `16 2 0 0 1 3 2 1 -2` |

## Design notes and scope

- **Fixed stacks.** The data stack is 32 cells, the return stack 16 (three
  cells per `do` frame: start pc, limit, index). Deliberate: Crush arrays can
  be mutated in place (`stk[i] = v`) but not grown from source, so a fixed
  buffer + depth pointer is the natural stack.
- **Control flow by scanning, not compiling.** `if`/`else`/`then` and
  `do`/`loop` resolve their jumps by scanning the token array for the matching
  token (with a nesting depth counter), so no growable jump table is needed.
- **Manual integer parsing.** There is no `to_int` in the standalone binary
  (`conv.*` lives behind the unbuilt `stdlib` feature), so `parse_int` walks
  the token's characters and accumulates `n * 10 + digit`.
- **Not implemented (honest scope boundary).** Colon definitions
  (`: word ... ;`) and a compile-time dictionary; multi-word string literals;
  a growable stack. The five programs above fit comfortably in the current
  design.
