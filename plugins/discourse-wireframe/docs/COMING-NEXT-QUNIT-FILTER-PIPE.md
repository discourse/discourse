# Investigate `bin/qunit --filter` mis-scoping (the `|` trap + `.gjs` path)

## Context

While verifying a test change we needed to run just two QUnit modules:

- `Integration | ui-kit | Modifier | dragAndDrop`
- `Integration | ui-kit | Modifier | dragAndDropMonitor`

Two separate scoping attempts both failed in confusing ways, costing real time
(one looked like a stalled run that was actually executing most of the suite).
Neither is the user's fault — the tooling makes single-file scoping a trap.
This note records the reproduction and starting points so we can fix it; it is
**not** a plan yet.

## Symptom 1 — a `|` in `--filter` is treated as a regex alternation

```bash
bin/qunit --standalone --filter "ui-kit | Modifier | dragAndDrop"
```

Intended: match the two modules above. Actual: the run launched the browser and
sat there for minutes appearing hung. It was not hung — the `|` was interpreted
as **regex alternation**, so the filter matched every test whose name contains
`ui-kit` **OR** `Modifier` **OR** `dragAndDrop` (i.e. a large fraction of the
core suite). Confirmed from the live Chrome process args, where the filter
reached the browser URL-encoded as a single param:

```
http://localhost:7357/<id>/tests?...&filter=ui-kit%20%7C%20modifier%20%7C%20draganddrop&...
```

The safe workaround today is a plain substring with **no** `|`:

```bash
bin/qunit --standalone --filter dragAndDrop   # matches both module names; 12 tests, fast
```

## Symptom 2 — a `.gjs` file path matches nothing

```bash
bin/qunit frontend/discourse/tests/integration/ui-kit/modifiers/drag-and-drop-test.gjs
# Global error: No tests matched with the filter: tests/.../drag-and-drop-test.gjs
```

Passing a `.gjs` test file (the documented usage, and what `bin/qunit --help`
advertises) produces **zero** matches. The file-path filter is sent to the
browser as `filePath=...drag-and-drop-test.gjs`, but the registered module's
recorded path almost certainly carries no `.gjs` extension after compilation, so
the equality/inclusion check never hits. `.js` file paths work; `.gjs` silently
matches nothing — and "no tests matched" reads like "the file has no tests"
rather than "the filter shape is wrong".

## Where it is wired (starting points)

- `bin/qunit` parses `-f/--filter` (`bin/qunit:59`) and forwards it verbatim to
  `pnpm ember exam --filter <value>` (`bin/qunit:262`). The file-path arg becomes
  `--file-path` (`bin/qunit:263`, built in `build_file_path_filter`, ~`:514`).
  There is also a separate `--module` option (`bin/qunit:90`).
- From `ember exam` the value reaches the in-browser QUnit `filter` URL param,
  read during boot (`frontend/discourse/tests/setup-tests.js`).
- QUnit's own filter semantics are the likely culprit for Symptom 1: a bare
  string is a case-insensitive substring match, but QUnit treats input as a
  **regex** under some shapes — `|` is the tell. Needs confirming against the
  pinned QUnit / ember-exam / ember-cli-test-loader versions.

## Investigation / open questions

1. **Exactly where does `|` become alternation?** QUnit's `filter` handling, or
   ember-exam / ember-cli-test-loader preprocessing? Pin it to a line in the
   dependency before deciding the fix layer.
2. **`--filter` vs `--module`.** Is `--module "Integration | ui-kit | Modifier | dragAndDrop"`
   the intended exact-module path, and does it sidestep the `|` problem? If so,
   `bin/qunit` could route a single-module request through `--module`
   automatically.
3. **`.gjs` file-path resolution.** Should `build_file_path_filter` strip the
   `.gjs`/`.js` extension (match on the extension-less module path), or should the
   browser-side matcher compare without extension? Either would make the
   advertised `bin/qunit path/to/test.gjs` usage actually work.
4. **Fail loud, not silent.** When a `--filter` / file-path scopes to zero tests,
   surface a clear hint ("did you pass a `.gjs` path?" / "`|` is regex — quote or
   use `--module`") instead of a bare "No tests matched".
5. **Docs.** Until fixed, `bin/qunit --help` examples should warn that `|` is
   regex and that `.gjs` paths don't filter; or the examples should use
   `--module` / extension-less paths.

## Desired outcome

Scoping a run to one or two specific `.gjs` test files (by path or by module
name, including names that contain `|`) works on the first try, or fails with a
message that tells you why.
