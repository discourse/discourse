# Test impact analysis

Runs only the specs a change can affect, from a map of which code each spec
file runs. Experimental.

## Recording a map

`TEST_IMPACT_RECORD=1` makes every RSpec process record, per spec file, the
methods it ran and the lines it ran outside methods (class-level blocks:
scopes, callbacks, event handlers), into `tmp/test_impact/recording-*.jsonl.gz`.
Then merge the recordings:

```sh
TEST_IMPACT_RECORD=1 bin/turbo_rspec spec/models spec/requests
script/test_impact/build_map            # -> tmp/test_impact/map.json.gz
```

Recording costs about a third more time. It can't run together with
`COVERAGE=1`, since both use Ruby's `Coverage`.

In CI, a pull request labeled `test-impact-record` records in the backend and
system jobs and uploads `test-impact-recordings-*` artifacts. The label takes
effect on the next push. `build_map` merges recordings from several jobs when
they are in one directory.

## Selecting specs

```sh
bin/rspec $(script/test_impact/select --base origin/main)
```

`select` diffs the working tree against the merge base with `--base`:

- a changed spec file is selected;
- a changed method selects the specs that ran it;
- a change outside any method selects the specs that ran that code, or, when
  nothing ran it (constants, associations, validations, which only run at
  load), every spec that ran the file;
- a rename selects every spec that ran the file.

On stderr it lists changed methods no spec ran, and changed files the map
doesn't cover (new files, YAML, JS, migrations). When the second list isn't
empty, the selection is incomplete.
