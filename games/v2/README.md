# games/v2: current-toolchain games on facet 0.3.0

`game_of_life` and `tictactoe` rewritten as proper CLIs. Each uses structs and `impl`, arrays, `while` loops
and an LCG seeded by `--seed` (no clock), and parses its arguments with
[facet](https://github.com/nixpt/facet) (`import facet { facet_run, facet_fail }`).

Set once (adjust to your checkout):

```sh
CRUSH_RUN=/workspace/bin/release/crush-run
FACET=/workspace/projects/facet
```

Both need `--max-steps` (the default 1,000,000-step quota is too small); `life.crush` also needs `--time`
because `--speed` calls `time.sleep` (the grant covers the whole program, so it is required even at
`--speed 0`). Grants go before `--`.

## game_of_life

```sh
$CRUSH_RUN run -L $FACET --time --max-steps 200000000 games/v2/game_of_life/life.crush -- --seed 7 --generations 10 -v
$CRUSH_RUN run -L $FACET --time --max-steps 200000000 games/v2/game_of_life/life.crush -- --headless -g 50 -vv
$CRUSH_RUN run -L $FACET --time --max-steps 200000000 games/v2/game_of_life/life.crush -- --help
```

Options: `-W/--width`, `-H/--height` (together; default 20x10), `-s/--seed`, `-d/--density` (percent alive, 0..100),
`-g/--generations`, `--speed MS` (pause per frame), `-v`/`-vv` (population; plus births and deaths),
`--watch` or `--headless` (mutually exclusive; watch, every frame, is the default).
Last lines: `summary: seed=.. size=WxH gens=.. pop=.. births=.. deaths=..`.

## tictactoe

```sh
$CRUSH_RUN run -L $FACET --max-steps 200000000 games/v2/tictactoe/tictactoe.crush -- --seed 3 --rounds 2 --x random --o first
$CRUSH_RUN run -L $FACET --max-steps 200000000 games/v2/tictactoe/tictactoe.crush -- --rounds 20 --x random --o minimax --headless -v
```

Options: `-x/--x` and `-o/--o` strategy (`random`, `minimax`, `first`), `-s/--seed`, `-r/--rounds`,
`-v`/`-vv` (a line per game with its moves; plus the final board), `--watch`/`--headless`.
Last line: `result: X=<n> O=<n> draw=<n>`.

The board is a 9-character string (`X`, `O`, `.`; cell 0 top-left, row-major) and `pick_move(strategy,
board, mark, rng)` is the single move chooser, so a later `--state <board> --move` mode is a thin wrapper.

## Tests

```sh
games/v2/test.sh                                   # exit 0 = all ok
CRUSH_RUN=... FACET_DIR=... POLISH=... games/v2/test.sh
UPDATE_GOLDEN=1 games/v2/test.sh                   # rewrite goldens after an intended change
```

Per game: golden-output compares of seeded runs (`<game>/golden/`), `--help` exits 0, an unknown flag exits 2,
`--watch --headless` exits 2 with the exclusive-group message, the same seed gives identical output, and
`polish check` has no errors (long spec-map lines give `P-LINE-LEN` warnings until crush-ast CRUSH-345).
