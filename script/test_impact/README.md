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
- the tables its queries named;
- the gems whose methods it ran (and, for the suite, the gems that loaded,
  ran at boot, or have native extensions);
- what it read and looked up as it loaded, such as a data file it generates
  examples from;
- for system specs, the browser JavaScript functions it ran.

QUnit records the same JavaScript per test file, through testem
(`frontend/discourse/patch-testem-test-impact.js`): the page waits at each
new top-level module while coverage of the one before is taken.

Theme QUnit (`bin/rake themes:qunit_all_official`) records the same way.
Themes are compiled by the server, so the recorder saves their source maps
(inline for a theme's tests) to `tmp/test_impact/js-maps/`, and the rake task
writes each theme's directory by id to `tmp/test_impact/themes.json`;
`resolve_js` then maps a theme's `theme-<id>/` sources to its files, in
`themes/<name>` or `tmp/themes/<name>`.

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
system and frontend jobs and uploads `test-impact-recordings-*`
artifacts. The label takes effect on the next push. `build_map` merges
recordings from several jobs when they are in one directory; the run's
`Test impact map` job does that and uploads the map as `test-impact-map`.

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
- a rename selects every spec that ran the file, under either path; a
  JavaScript file deleted and added back as TypeScript (or the reverse) is a
  rename;
- a new file selects the specs that read files in its directory, and
  otherwise nothing: it runs through the changed code or new specs that load
  it, which select their own. Initializers, plugin outlet connectors and
  route maps, which run without being named, are outside the map;
- a change in `config/site_settings.yml` or a plugin's `settings.yml` selects
  the specs that read the setting it is in, and those that read the file;
- a change in a server locale file selects the specs that looked up its key,
  or a key above or below it; outside English, only those that used that
  locale, plus those that read the file;
- any other changed file selects the specs that read it, except QUnit tests,
  type tests, documentation and what the Tests workflow ignores or never runs
  (the migrations tooling, import and benchmark scripts, linter and editor
  configuration), which select nothing when no spec ran or read them;
- a migration selects the specs that queried a table it names, in its schema
  calls, its SQL, or as a model class (`Chat::Message` for `chat_messages`);
- `db/structure.sql` selects nothing: the test database is migrated, and CI
  checks the dump in a step of its own;
- deleting a file no spec loaded or read selects nothing;
- a `Gemfile.lock` change selects the specs that ran the gems whose entries
  it changes (a dependency line belongs to the gem above it), plus the specs
  that read the lockfile; a gem the suite never loaded selects nothing.

On stderr it lists changed methods no spec ran, and changed files the map
doesn't cover: new files that run by convention, JavaScript no spec loads,
client locales, migrations that name no table a spec queried, settings or
locale changes that name no setting or key, changes to methods that ran at
boot or in the suite hooks (which no spec is charged with), and dependency
changes: `Gemfile`, `package.json`, pnpm's lockfile and workspace, and
lockfile changes to a gem that ran at boot, has a native extension (whose C
code Coverage doesn't see), or that no spec ran, or to anything but gem
entries.
When the second list isn't empty, the selection is incomplete.

## Selecting in CI

Every push to main runs everything and records, and uploads the map. Pull
requests run a selection, unless labeled `test-impact-full` (or
`test-impact-record`); pushes to release branches run everything.
Each job of `.github/workflows/tests.yml` downloads the newest
`test-impact-map` artifact recorded on main, or failing that on the branch the
pull request merges into or its own, from runs of this repository, and
`script/test_impact/ci_select` decides what it runs of the pull request's
changes against the branch it merges into:

- `full`: the job's whole suite, when anything changed is outside the map or
  there's no map;
- `none`: no tests, when nothing selected belongs to the job;
- `list`: the selected spec or test files that belong to the job.

Theme tests, in `themes/` and the official themes cloned into `tmp/themes/`,
are selected like the rest; theme QUnit runs the selected tests' themes whole
(`TEST_IMPACT_THEMES`). A job the map records no tests for runs whole. The
job's setup still runs when it selects none.

The map has the line numbers of the commit it was recorded at, which
`build_map` notes. A pull request's base is usually a few commits past it, so
`select` and `ci_select` move each hunk into the map's line numbers through the
file's changes in between (fetching the map's commit in CI); a hunk on lines
that changed in between covers everything that replaced them.
