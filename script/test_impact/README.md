# Test impact analysis

Runs only the specs a change can affect, from a map of what each spec file
depends on. Experimental.

## Recording a map

`TEST_IMPACT_RECORD=1` makes every RSpec process record, per spec file:

- the methods it ran, and the lines it ran outside methods (class-level
  blocks: scopes, callbacks, event handlers);
- the site settings it read;
- the translation keys and locales it looked up;
- the non-Ruby files in the repository it read (fixtures, templates, data);
- for system specs, the browser JavaScript functions it ran.

QUnit records the same JavaScript per test file, through testem
(`frontend/discourse/patch-testem-test-impact.js`): the page waits at each
new top-level module while coverage of the one before is taken.

Settings and translations are loaded once at boot, so the lookups are what
tell specs apart. Recordings go to `tmp/test_impact/recording-*.jsonl.gz`.
Then merge them:

```sh
TEST_IMPACT_RECORD=1 bin/turbo_rspec spec/models spec/requests spec/system
TEST_IMPACT_RECORD=1 bin/qunit --standalone
script/test_impact/resolve_js           # bundle ranges -> source files
script/test_impact/build_map            # -> tmp/test_impact/map.json.gz
```

JavaScript coverage comes from Chrome's profiler, taken by
`script/test_impact/cdp_coverage` over a DevTools port of its own (each
browser gets one while recording): a page's coverage through the test's
Playwright client takes minutes. It is recorded as bundle line/column ranges;
`resolve_js` maps them to source files through the build's source maps, so it
must run where that build is. After that, a `.js`, `.gjs` or `.ts` file is in
the map like a Ruby file.

Recording costs about a third more time for backend specs and a quarter for
system specs. It can't run together with `COVERAGE=1`, since both use Ruby's
`Coverage`.

In CI, a pull request labeled `test-impact-record` records in the backend,
system and frontend jobs (not themes) and uploads `test-impact-recordings-*`
artifacts. The label takes effect on the next push. `build_map` merges recordings from several jobs when
they are in one directory.

## Selecting specs

```sh
specs=$(script/test_impact/select --base origin/main)
bin/rspec $(grep '_spec\.rb$' <<< "$specs")
bin/qunit $(grep -v '_spec\.rb$' <<< "$specs")
```

`select` diffs the working tree against the merge base with `--base`:

- a changed spec or QUnit test file is selected;
- a changed method or function selects the specs that ran it (for nested
  JavaScript functions, the innermost one the change is in);
- a change outside any method selects the specs that ran that code, or, when
  nothing ran it (constants, associations, validations, which only run at
  load), every spec that ran the file;
- a rename selects every spec that ran the file;
- a change in `config/site_settings.yml` or a plugin's `settings.yml` selects
  the specs that read the setting it is in;
- a change in a server locale file selects the specs that looked up its key,
  or a key above or below it; outside English, only those that used that
  locale;
- any other changed file selects the specs that read it, except QUnit tests
  and documentation, which select nothing when no spec ran or read them.

On stderr it lists changed methods no spec ran, and changed files the map
doesn't cover (new files, JavaScript no system spec loads, client locales,
migrations, and settings or locale changes that name no setting or key).
When the second list isn't empty, the selection is incomplete.
