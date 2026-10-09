# caison-parsor

A **CAISON parser** written in Crush — single-pass, emitting the SPEC §6 JSON projection directly during parse.

CAISON ([nixpt/caison](https://github.com/nixpt/caison), Crush AI-native Semantic Object Notation, SPEC v1.0) is a JSON-shaped config format plus four AI-native primitives:

- **semantic keys** — `~"billing or refund issues": "route to support"`
- **confidence** — `temperature: 21.5 ~0.8`
- **annotations** — `port: 8080 @wip { owner: "foreman" }`
- **synthesized values** — `accent: @synthesize("a complimentary color")`

## Why single-pass?

The Crush runtime (as of 2026-10-04) has no nominal structs and forbids field access on function parameters, so a node-tree IR cannot cross function boundaries. Instead, parser state threads as `(src, pos)` scalars, and the JSON projection — which is what the conformance corpus tests — is emitted as a string during the parse. Nothing is lost.

## Run

```bash
crush-run run caison-parsor.crush --cap io.print
```

Parses the embedded sample document (covering all four primitives, sections, and the `@caison` version directive) and prints its JSON projection. To parse your own document, replace `sample_doc()` or call `parse_document(your_text)`.

## Verification

- 6/6 valid conformance vectors pass (`basic`, `confidence`, `annotation`, `section`, `semantic_key`, `synthesize`)
- 4/4 invalid vectors correctly report errors (`duplicate_key`, `missing_colon`, `unclosed_object`, `confidence_out_of_range`)

## Runtime constraints worked around

Documented in the file header — includes non-short-circuiting `&&`, the `"\r"` lexer bug, manual float parsing (no `conv.*` in this build), and uncatchable parse errors.
