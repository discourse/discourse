# PR split — how to work on this branch while its layers are in flight

`select-kit-rework` is an **integration branch**, not a PR branch. It carries the select family plus
seven upstream layers that were built or hardened here only because select needed them. Those layers
are being peeled off into separate PRs against `main` so each can be reviewed on its own merit,
leaving draft PR [#41534](https://github.com/discourse/discourse/pull/41534) reduced to select itself.

**If you are picking this up mid-flight, read the status table, then the rules.** The carved branches
are one-way *exports* from this branch's final tree. This branch stays the place the work happens.

Why a plain rebase is wrong here, and why the trunk is not being split yet, are both explained below.
Do not re-derive either decision without new information.

## Status

Tick a row when its PR merges, and merge `main` into `select-kit-rework` in the same pass. A layer
marked merged means its files are **upstream** and no longer this branch's to change directly.

State is ☑ merged · ◐ ready for review · ○ draft, plus the review decision where there is one. Read
it from GitHub rather than from memory (`gh pr view <n> --json state,isDraft,reviewDecision`); these
flip outside this branch and the table goes stale silently.

| # | Layer | PR | State | Paths it owns |
|---|---|---|---|---|
| 1 | float-kit | [#42376](https://github.com/discourse/discourse/pull/42376) | ☑ merged · approved | `frontend/discourse/float-kit/**`, `tests/integration/components/float-kit/{d-menu,d-tooltip,apply-floating-ui}-test.gjs` |
| 2 | a11y announcement composition | [#42377](https://github.com/discourse/discourse/pull/42377) | ○ draft · approved | `app/services/a11y.js`, `tests/integration/components/a11y/live-regions-test.gjs`, `app/ui-kit/d-icon-grid-picker/content.gjs`, `tests/integration/components/d-icon-grid-picker-test.gjs` |
| 3 | ui-kit primitive fixes | [#42378](https://github.com/discourse/discourse/pull/42378) | ◐ ready · review required | `app/ui-kit/d-async-content.gts`, `app/ui-kit/modifiers/d-observe-intersection.js`, `app/ui-kit/d-load-more.gjs` |
| 4 | DSkeleton | [#42380](https://github.com/discourse/discourse/pull/42380) | ◐ ready · review required | `app/ui-kit/d-skeleton.gts`, `common/components/d-skeleton.scss`, `tests/integration/ui-kit/d-skeleton-test.gjs` |
| 5 | dRovingFocus | [#42381](https://github.com/discourse/discourse/pull/42381) | ○ draft | `app/ui-kit/modifiers/d-roving-focus.ts`, `tests/integration/ui-kit/modifiers/d-roving-focus{,-windowed}-test.gjs` |
| 6 | DVirtualList | [#42382](https://github.com/discourse/discourse/pull/42382) | ○ draft | `app/ui-kit/{d-virtual-list.gts,modifiers/d-virtualizer.ts,lib/virtualizer.js,helpers/d-element.gts}`, `common/components/d-virtual-list.scss`, `tests/integration/ui-kit/d-virtual-list-*.gjs`, `tests/unit/ui-kit/virtualizer-test.js`, `tests/setup-tests.js`, `package.json` + `pnpm-lock.yaml`, styleguide `sections/molecules/virtual-list.gjs` |
| 7 | styleguide infrastructure | [#42385](https://github.com/discourse/discourse/pull/42385) | ○ draft | styleguide `components/styleguide-{group,groups,subnav}.gjs`, `styleguide-example.gjs`, `lib/inline-code.js`, `controllers/styleguide/show.js`, `routes/styleguide/show.js`, `templates/styleguide/show.gjs`, `README.md`, **`config/locales/client.en.yml`** (the three `example.*` keys, per the shared-file table below), `plugin.rb` (its asset filter dropped the plugin whenever assets were resolved without a request, which made its own JS tests unloadable), `spec/system/{smoke_test_spec.rb,styleguide_example_spec.rb,page_objects/pages/styleguide.rb}`, `test/javascripts/**`, plus the `class="half-size"` removal from `sections/{molecules/navigation-stacked,organisms/basic-topic-list}.gjs` |

Everything not listed above stays on this branch: the select family, the `modifySelectKit` bridge, the
styleguide select sandbox and its system specs, and these trackers.

## Rules

### Merge `main` in. Never rebase this branch.

A rebase replays all ~94 commits against a `main` that already holds a layer's final files. The commit
that introduced them conflicts, and so does every later commit that touched them, once per layer.
Because the carve is byte-identical to what is already here, `git merge main` instead resolves against
tree state and lands as a near-no-op per layer.

The merge commits do not matter: Discourse squash-merges, so #41534 becomes one commit regardless.

```bash
git checkout select-kit-rework
git fetch origin && git merge origin/main
git diff --shortstat origin/main...HEAD   # should have shrunk by the merged layer
```

That shrinking diff is both the progress meter and the proof the carve was faithful. If a merged
layer's files still show up in it, the carve drifted; reconcile before continuing.

Squashing this branch to one commit before a rebase remains available as a last resort (it was used
for the `floatkit-to-ts` re-home), but it should not be needed and throws away the history.

### Two directions for changes

**A layer PR gets review feedback** → fix it on the layer branch, then merge that branch into
`select-kit-rework`. This pre-resolves the eventual `main` merge. It is also the one case that
produces a genuine conflict, since `main` then holds a version that differs from this branch's; the
conflict is small and confined to that layer's files.

**A layer's file needs changing for select's sake** → change it here as usual, then either push the
same hunk to the layer branch if its PR is still open, or queue it as a follow-up PR if that layer
already merged. Never let the two versions silently diverge.

### Carving an export branch

Path-carve from this branch's **final** tree. Do not cherry-pick: the ~94 commits interleave later
fixes into earlier features (dRovingFocus alone was hardened across four commits separated by select
work, and the first commit is a squashed wip blob), so a replay ships known-broken intermediate
states.

```bash
git worktree add ~/discourse/core/worktrees/<layer> -b <layer> origin/main
cd ~/discourse/core/worktrees/<layer>
pnpm install                                        # a fresh worktree has no node_modules
mkdir -p tmp                                        # nor tmp/, which --standalone needs
git checkout select-kit-rework -- <that layer's paths>
```

Without `tmp/`, `bin/qunit --standalone` dies on
`Process.spawn: No such file or directory - .../tmp/test_server_4566.log` before running anything.

**Re-stage after fixing anything in a carved file.** `git checkout <branch> -- <paths>` stages the
carve, so a follow-up edit leaves the file with staged content differing from both the worktree and
HEAD. `script/assemble_ember_build.rb` hashes the core tree through git and refuses that state, so
`--standalone` fails during the build with `the following file has staged content different from
both the file and the HEAD` after the bundle has already been written, which reads like a build
error rather than a staging one. `git add` the file and re-run.

Before pushing, confirm the carve took nothing extra and clobbered nothing upstream:

```bash
git status --short                                       # exactly this layer's files
git diff select-kit-rework -- <paths>                    # empty: carve matches the branch
git log <merge-base>..origin/main -- <paths>             # empty: no upstream change overwritten
```

That third check matters because `main` moves under you. A wholesale
`git checkout select-kit-rework -- <dir>` reverts any upstream edit to a file in that directory
made since the branch's merge-base, and nothing else in the flow would catch it.

One scratch worktree, reused per layer, is enough. Each export is carve → verify → push, and the
worktree is only needed again if review feedback arrives.

### Six files are shared between layers — hand-edit, never wholesale checkout

`git checkout select-kit-rework -- <file>` on any of these drags in other layers' work:

| File | How it splits |
|---|---|
| `app/assets/stylesheets/common/components/_index.scss` | One `@import` line each: `d-skeleton` → 4, `d-virtual-list` → 6, `d-combobox` → select. Trivial conflicts by design. |
| `plugins/styleguide/assets/stylesheets/styleguide.scss` | By top-level block. Furniture (7) keeps everything up to and including `.styleguide-example`, plus `.more-topics-examples`; the select sandbox takes the whole `.select-*` run **including `.styleguide-example.--wide`**, whose body only sets a select control width, and the `--styleguide-control-width` token defined inside `.select-examples`; `.styleguide-virtual-list` → 6. Do not strip by pattern: the blocks carry leading comments and comma-joined selector lists, and a regex pass leaves dangling selectors that still lint. Map exact block boundaries by brace-matching, then slice by line range. |
| `plugins/styleguide/.../lib/styleguide.js` | One import plus one `SECTIONS` entry each: `virtualList` → 6, `select` → sandbox. |
| `plugins/styleguide/config/locales/client.en.yml` | By key: `example.{toggle_code,try_this,code_region}` → 7, `virtual_list:` → 6, `select:` → sandbox. |
| `plugins/styleguide/spec/system/smoke_test_spec.rb` | **A layer that adds a styleguide section MUST add its `sections` hash entry**, because the spec asserts the per-category count matches (`existing_items.size == items.size`) and asserts each page's heading equals the hash `title`. So `virtual-list` → 6, `select` → sandbox, and the title must match the locale value exactly. The 13 select `it` blocks and `include ThemeScreenshotMarker` → sandbox; the four furniture tests already exist on `main`. |
| `plugins/styleguide/spec/system/page_objects/pages/styleguide.rb` | The generic example helpers (address by visible title) → 7; anything resolving an example by a DSelect trigger attribute → sandbox. |

Every other path belongs to exactly one layer, including `tests/setup-tests.js`, `package.json`,
`pnpm-lock.yaml`, `d-element.gts` and `deprecation-workflow.js`.

Also note `@use "lib/viewport";` at the top of the branch's `styleguide.scss` is dead — nothing
references it — so it was not carried into layer 7 and should be dropped from this branch too.

## Don't

- **Don't rebase `select-kit-rework`.** Merge `main` in. See above for why.
- **Don't develop on an export branch.** They are derived artifacts. The exception is a fix answering
  review feedback on that layer's own PR, which then gets merged back here.
- **Don't retarget #41534** onto a layer branch. It stays based on `main`. Its diff looks large until
  the layers land, which is fine for a draft.
- **Don't split the select trunk yet.** The family (~19k lines), the `modifySelectKit` bridge and the
  styleguide sandbox are three clean cuts, but they only pay off at review time and cost immediately:
  every fix would need routing to the right one of three branches and rebasing through the other two.
  #41534 is still a draft and still churning. Revisit when it is review-ready.
- **Don't delete an export branch** until its PR has merged or been closed.
- **Don't move the trackers or the RFC** as a side effect of a carve. `SELECT-KIT-REPLACEMENT-RFC.md`
  is still at the repo root and its placement is an open question that rides with #41534.

## Verification

Per export branch, before pushing:

- **Load the `discourse-qunit` skill before any `bin/qunit` run**, including a re-run of something that
  just passed.
- Exact `--module` runs for that layer's suites.
- **A layer that adds NEW test files must wipe `dist` first, or those files never run.**
  `--standalone` does not reliably re-expand the test glob: it can print
  `[assemble_ember_build] Reusing existing core ember build` and serve a bundle built before the
  files existed. The failure is silent and looks like success — the run reports `# pass` with no
  failures, because only the *pre-existing* modules in the target path ran. Carving `dRovingFocus`
  reported a green `# tests 6` (a neighbouring modifier's suite) where the real figure was
  `# tests 55`. Always check which modules actually ran:
  `grep -E '^ok ' <log> | sed -E 's/^ok [0-9]+ \[[0-9]+ ms\] - //;s/:.*//' | sort | uniq -c`.
  `rm -rf frontend/discourse/dist tmp/cache/assets` forces the re-glob.
- **One full-suite run per build, and wipe `dist` first.** Repeated `--standalone` runs in one
  worktree re-digest chunks while a previously generated index is still live, so a later run fetches
  a digest that no longer exists and dies partway through. The tell is a **short test count** plus
  `Failed to fetch dynamically imported module: .../<chunk>-<digest>.digested.js`; a complete core
  run is ~10.9k tests, so anything in the hundreds or low thousands is truncated, not green and not
  a real failure list. Recover with
  `rm -rf tmp/stylesheet-cache tmp/cache/assets frontend/discourse/dist`.
- Expect the first `--standalone` run after any tree change (including `git checkout`/`reset`) to
  trip the watchdog with `Browser made no test progress ... outside an active test` and
  `# tests 1 / # fail 1`. That is a startup stall, not a result. Re-run once.
- **Browser startup is intermittently flaky, and `Browser failed to connect within 45s. testem.js
  not loaded?` with `# tests 1 / # fail 1` is a startup failure, not a result.** Keep the default
  timeout and let it fail fast, then re-run. Do **not** raise `--browser-start-timeout`: a run at
  150s failed the same way, so a longer budget only buys a slower failure. Cause is not yet
  identified; a narrow `--module` run has started reliably where a whole-directory run repeatedly
  did not, which may be coincidence.
- Chrome's `bind() failed: Address already in use` line is a separate red herring.
  `frontend/discourse/testem.js` hardcodes `--remote-debugging-port=3001` outside CI (CI passes `0`
  and lets the OS assign), so it collides with anything holding 3001, but Chrome goes on to report
  `DevTools listening on ws://[::1]:3001` and startup failed the same way after 3001 was freed.
  Making that port dynamic is tracked in the testem-startup handoff, not here.
- **Attribute every failure against a baseline before believing it.** `main` is not always green
  here: `Acceptance: composer buttons API: buttons can support a shortcut` fails on a clean
  checkout, independent of this work. Cheapest attribution is to run the named test in isolation on
  the layer branch and on clean `main`; only escalate to a full-suite comparison if it passes in
  isolation on both.
- `bin/lint --fix <changed files>` and `pnpm lint:types`.
- Layer 1 additionally needs the **full JS suite**: making `settled()` await float-kit positioning
  alters test timing everywhere.
- **A plugin system spec serves a stale plugin bundle until you run
  `bin/rake assets:precompile:build_plugins`, and it passes anyway.** Carving the styleguide
  furniture, the full smoke spec reported a green 50 examples while the browser was still being
  served `main`'s components: the assertions it makes (headings, index links) hold with or without
  the change, so the run proved nothing. The tell is an assertion on something only the new code
  emits failing with `Unable to find css ...` while everything else passes. The rebuild takes about
  8 seconds, far less than the run it invalidates.
- After rebuilding, confirm the spec actually exercises the new code. An assertion that fails on the
  stale bundle and passes on the rebuilt one is the proof; without one, a plugin system spec cannot
  tell your change apart from `main`.

After each `main` merge into this branch, re-verify here too: the select integration and unit suites
plus the styleguide system specs. A layer that merged with review-requested changes is exactly where
this branch drifts silently.
