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

| # | Layer | PR | State | Paths it owns |
|---|---|---|---|---|
| 1 | float-kit | — | ☐ not opened | `frontend/discourse/float-kit/**`, `tests/integration/components/float-kit/{d-menu,apply-floating-ui}-test.gjs` |
| 2 | a11y announcement composition | — | ☐ not opened | `app/services/a11y.js`, `tests/integration/components/a11y/live-regions-test.gjs`, `app/ui-kit/d-icon-grid-picker/content.gjs`, `tests/integration/components/d-icon-grid-picker-test.gjs` |
| 3 | ui-kit primitive fixes | — | ☐ not opened | `app/ui-kit/d-async-content.gts`, `app/ui-kit/modifiers/d-observe-intersection.js`, `app/ui-kit/d-load-more.gjs` |
| 4 | DSkeleton | — | ☐ not opened | `app/ui-kit/d-skeleton.gts`, `common/components/d-skeleton.scss`, `tests/integration/ui-kit/d-skeleton-test.gjs` |
| 5 | dRovingFocus | — | ☐ not opened | `app/ui-kit/modifiers/d-roving-focus.ts`, `tests/integration/ui-kit/modifiers/d-roving-focus{,-windowed}-test.gjs` |
| 6 | DVirtualList | — | ☐ not opened | `app/ui-kit/{d-virtual-list.gts,modifiers/d-virtualizer.ts,lib/virtualizer.js,helpers/d-element.gts}`, `common/components/d-virtual-list.scss`, `tests/integration/ui-kit/d-virtual-list-*.gjs`, `tests/unit/ui-kit/virtualizer-test.js`, `tests/setup-tests.js`, `package.json` + `pnpm-lock.yaml`, styleguide `sections/molecules/virtual-list.gjs` |
| 7 | styleguide infrastructure | — | ☐ not opened | styleguide `components/styleguide-{group,groups,subnav}.gjs`, `styleguide-example.gjs`, `helpers/inline-code.js`, `controllers/styleguide/show.js`, `routes/styleguide/show.js`, `templates/styleguide/show.gjs`, `README.md`, `spec/system/{smoke_test_spec.rb,page_objects/pages/styleguide.rb}` |

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
git checkout select-kit-rework -- <that layer's paths>
```

One scratch worktree, reused per layer, is enough. Each export is carve → verify → push, and the
worktree is only needed again if review feedback arrives.

### Four files are shared between layers — hand-edit, never wholesale checkout

`git checkout select-kit-rework -- <file>` on any of these drags in other layers' work:

| File | How it splits |
|---|---|
| `app/assets/stylesheets/common/components/_index.scss` | One `@import` line each: `d-skeleton` → 4, `d-virtual-list` → 6, `d-combobox` → select. Trivial conflicts by design. |
| `plugins/styleguide/assets/stylesheets/styleguide.scss` | By top-level selector: `.styleguide-virtual-list` → 6; `.styleguide-example.--wide` and the subnav/groups rules → 7; every `.select-*`, `.select-hero`, `.select-showcases`, `.select-keyboard`, `.select-aria-probe` → sandbox. |
| `plugins/styleguide/.../lib/styleguide.js` | One import plus one `SECTIONS` entry each: `virtualList` → 6, `select` → sandbox. |
| `plugins/styleguide/config/locales/client.en.yml` | By key: `example.{toggle_code,try_this,code_region}` → 7, `virtual_list:` → 6, `select:` → sandbox. |

Every other path belongs to exactly one layer, including `tests/setup-tests.js`, `package.json`,
`pnpm-lock.yaml`, `d-element.gts` and `deprecation-workflow.js`.

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
- `bin/lint --fix <changed files>` and `pnpm lint:types`.
- Layer 1 additionally needs the **full JS suite**: making `settled()` await float-kit positioning
  alters test timing everywhere.
- Layer 7 adds new plugin files, so its smoke spec needs
  `bin/rake assets:precompile:build_plugins` and a running `bin/dev` to avoid serving a stale dist.

After each `main` merge into this branch, re-verify here too: the select integration and unit suites
plus the styleguide system specs. A layer that merged with review-requested changes is exactly where
this branch drifts silently.
