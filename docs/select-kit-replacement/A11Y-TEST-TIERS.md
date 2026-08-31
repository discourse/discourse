# Automated a11y testing for the select rework

Outcome of the spike on making accessibility regressions catchable without a human listening to a
screen reader. Four tiers, each justified by a defect class the others cannot see.

## Why tiers rather than one suite

The motivating regression is K5 in [SANDBOX-A11Y-REMEDIATION.md](./SANDBOX-A11Y-REMEDIATION.md): a
combobox that opened with no cursor at all, while the rendering test asserting "keyboard opening
activates the first option" **passed**. The assertion was correct; the environment was wrong, because
a rendering test mounts rows before the roving modifier installs.

So coverage is not the variable that matters. What matters is which *fidelity gap* a tier closes.

| Tier | Instrument | Sees | Blind to |
|---|---|---|---|
| 1 | APG pattern suite (QUnit) | roles, names, keyboard, `aria-activedescendant` wiring, position contiguity | mount-order timing; announcements |
| 2 | Playwright aria snapshot + cursor contract (system spec) | real-browser timing, real virtualizer, the cursor → **K5** | announcements |
| 3 | axe, recorded floor (QUnit) | malformed ARIA, missing accessible names | wrong-but-valid roles; the cursor |
| 4 | Announcement log (QUnit) | utterance sequence, count, politeness | mount-order timing (same as tier 1) |

Tier 2 is the only one that would have caught K5. Tier 1 runs in the same environment that missed it.

## Tier 1 — APG pattern suite

- `frontend/discourse/tests/helpers/aria-patterns/assertions.js` — registers `assert.combobox()`.
- `frontend/discourse/tests/helpers/aria-patterns/combobox.gjs` — `ComboboxPatternTests({ name, renderer, supports })`.
- `frontend/discourse/tests/integration/ui-kit/select/d-select-apg-test.gjs` — three DSelect variants.

Test names are the `data-test-id` values from `w3c/aria-practices`
(`test/tests/combobox_select-only.js`, 36 assertions keyed to rows in the APG's own prose tables), so
coverage is auditable against the spec rather than against our own idea of completeness.

`hasCursorOn` reports **absent**, **dangling** and **wrong row** as three separate failures.
`aria-activedescendant` is written imperatively by `dRovingFocus` (`d-roving-focus.ts:715`), not by a
template, so a plain `hasAttribute` check collapses the distinction that K5 turned on.

`supports` is a capability declaration, not an escape hatch: every APG behaviour defaults to **on**,
and a renderer that lacks one opts out at its call site where the opt-out reads as the documented
gap it is.

### Two conformance gaps found

Both are declined in `d-select-apg-test.gjs` with the reason inline:

1. **Home/End do not open the listbox.** The opening keys are Enter/Space/ArrowDown/ArrowUp
   (`d-select.gts:1377`). APG's select-only pattern also opens on Home and End, onto the first and
   last option.
2. **Alt+ArrowUp does not close and commit.** Nothing in `DSelect` or `dRovingFocus` reads `altKey`.
   A consequence worth noting: Alt+ArrowDown "opens" only because the modifier is ignored and the
   plain key is handled, so the modifier is untested by construction until this is implemented.

## Tier 2 — system-spec fidelity layer

- `spec/system/page_objects/components/ui_kit/d_select.rb` — `playwright_locator`,
  `panel_aria_snapshot`, `active_descendant_state`, `mounted_positions`.
- `plugins/styleguide/spec/system/d_select_a11y_contract_spec.rb`.

**No new dependency.** `playwright-ruby-client 1.60.0` (already present via
`capybara-playwright-driver`) ships `locator.aria_snapshot` and `to_match_aria_snapshot`, and the
latter polls like any Playwright web-first assertion. Styleguide system specs already run in the
existing `core-plugins/system` CI lane.

**Aria snapshots cannot see the cursor.** Playwright's serializer never reads
`aria-activedescendant`; its `[active]` marker is real DOM focus and is emitted only in AI mode.
Serialized props are exactly `url, checked, disabled, expanded, invalid, level, pressed, selected`.
The spec asserts this boundary explicitly, so a green snapshot is never mistaken for a verified
cursor — and if Playwright ever starts serializing it, that test fails and tells us.

## Tier 3 — axe as a recorded floor

- `frontend/discourse/tests/helpers/aria-patterns/axe.js` — `auditCombobox`.
- `frontend/discourse/tests/integration/ui-kit/select/d-select-axe-test.gjs`.

Gates on nine unambiguous rules and *records* everything else, so an axe change never blocks an
unrelated PR. Disabled rules each carry the reason they fire falsely on a composite widget
(`aria-required-children` on grouped listboxes, `aria-hidden-focus` on a closing portal).

Set expectations accordingly: axe has no rule for "this role is the wrong role", and its entire
`aria-activedescendant` check is `!!(value && doc.getElementById(value))` — the target's role,
ownership and visibility are unchecked. **axe would not have caught K5.**

## Tier 4 — announcement contracts

Covers what no other tier can: the composed utterance, and how many times it is spoken. Several open
remediation items are defects where every attribute is individually correct and only the
announcement is wrong.

Delivered as two owned helpers (see below). A virtual screen reader was also built, measured, and
dropped on evidence — that experiment is recorded here because the null result is the useful part.

### The virtual screen reader was tried properly and is not needed

`@guidepup/virtual-screen-reader` is the only simulated screen reader that exists. It was added
(pinned `0.32.1`, imported from `@guidepup/virtual-screen-reader/browser.js` — its bundle is
self-contained), pointed at the one question nothing else asks — **traversal**: is content reachable
at all, and in what order — and run as `d-select-traversal-test.gjs`, five tests, 5/5 passing.

It works. It boots in real Chrome under QUnit, and it composes genuine utterances unprompted
(`"option, core, selected, position 1, set size 4"`). Two things came out of it:

1. **K4 does not reproduce for multi-select chips.** They are reachable and named
   (`"button, Archived Press Backspace or Delete to remove"`). Whatever "tag chips not read" is, it is
   not this configuration — likely tag-picker-specific, or a VoiceOver behaviour no simulator models.
2. **The chip's accessible name lacks the comma its own code comment promises.** `d-select.gts`
   documents `"Orange, Press Backspace or Delete to remove"`; ACCNAME joins `aria-labelledby` targets
   with a space, so a reader gets one run-on phrase.

**It was then dropped, because Tier 2 sees the same thing with higher fidelity.** A snapshot of the
trigger via `playwright_trigger_locator` contains both the chip name and the run-on
(`match(/Archived Press Backspace/)`), computed by the *browser's* ACCNAME rather than Guidepup's
partial reimplementation (self-reported 396 WPT passing / 81 failing / 338 skipped). Same coverage, no
frozen dependency, instrument already installed. Both findings above are now pinned by Tier 2 tests.

Re-adding it would only be worth it for a question Tier 2 genuinely cannot express — reading *order*
across a subtree is the plausible candidate, and the aria snapshot's tree order covers most of it.

### The two halves

Announcements and utterances are different questions and are answered by different files.

| File | Question |
|---|---|
| `announcements.js` | What did the live regions say, how many times, how politely? |
| `utterances.js` | What does a row say when the cursor lands on it? |

`utterances.js` composes role, accessible name, position and state into one phrase. The name comes from
`computeAccessibleName()` in `dom-accessibility-api` (the implementation behind Testing Library's
`getByRole`, 102.9M weekly downloads) rather than `textContent`, because a row's name can come from
`aria-label`, `aria-labelledby`, or a subtree with presentational children — reading text would
silently disagree with what is announced. This is the accname computation the plan called for and the
styleguide probe never had (`select-aria-probe.gjs:35` still falls back to `textContent`).

**Why a separate instrument from the attribute checks.** `assert.combobox().hasContiguousPositions()`
checks `aria-posinset` across every rendered row, and the system-spec aria snapshot does not serialize
position at all — Playwright emits only `url, checked, disabled, expanded, invalid, level, pressed,
selected`. So a defect that lives in the *composition* is invisible to both. `navigablePositions()`
parses positions back out of the spoken phrase, filtered to rows the cursor can reach; including
unreachable rows is exactly what makes the positions look contiguous.

### It reproduced an open defect on the first run

`reachable rows speak contiguous positions` observes **`[1,2,4]`** against a fixture of four rows whose
third is disabled: the unreachable row consumes position 3, and every row claims "of 4" where only
three are visitable. That is the miniature of "Watching, 4 of 6" one press from "6 of 6", listed as
still open in [SANDBOX-A11Y-REMEDIATION.md](./SANDBOX-A11Y-REMEDIATION.md) and until now findable only
by listening.

It is a `test.todo`, not a `skip` and not an inverted assertion: it stays executable, reports green
while the defect exists, and **fails once the defect is fixed**, which is the prompt to promote it.
Asserting the observed `[1,2,4]` would encode the bug, and that doc has a section on tests that did.

The invariant is agnostic about the remedy — what a reader hears must match the rows they can visit —
so either candidate fix satisfies it: make disabled rows navigable (the doc's stated preference), or
stop them consuming positions.

Assertions are on **sequence, count and politeness only** — never on exact spoken text. Path A's
phrasing is Guidepup's own invention and matches no real screen reader, so pinning it would couple
the suite to a package version rather than to a behaviour. This is the discipline whose absence got
Semrush's own select VoiceOver test skipped.

### Every negative assertion needs a positive control

Both paths assert mostly *absences* (`[]`, `count === 0`). All of those pass vacuously if the
observer never fires, so each path carries a test that makes a real announcement and asserts it
appears. Those are the tests that give the rest their meaning; do not delete them as redundant.

Path B additionally **throws** when the shared live regions are absent rather than reporting an empty
log — the exact trap the styleguide probe fell into, where silence and a broken component were
indistinguishable.

## The tiering was verified, not assumed

The claim that tier 2 closes a gap tier 1 cannot is measured, not argued. K5 was reintroduced by
making `#armPendingSeed()` in `d-roving-focus.ts` an early return, and both suites were run against
it:

| Suite | With K5 present |
|---|---|
| Tier 1 — `APG \| combobox` (QUnit, 64 tests) | **64 pass, 0 fail** — blind |
| Tier 2 — `d_select_a11y_contract_spec` (8 examples) | **4 fail** — caught |

Tier 2's diagnostic was `expected a resolvable aria-activedescendant, got {"status" => "absent"}` —
the same `ad: "absent"` the remediation doc recorded when it measured K5 in a browser.

The three **aria-snapshot** examples passed with the bug present, which is the empirical form of the
warning above: a green accessibility-tree snapshot says nothing about the cursor.

Reproduce it before trusting a future change to either tier. A tier whose failure has never been
observed has not been shown to test anything.

## Each tier was validated by mutation, and one verdict reversed

A tier that has never been observed failing has not been shown to test anything. Each was therefore
given a defect to catch, with a control arm proving it can also pass.

| Mutation | Tier 1 | Tier 2 | Tier 3 axe | Tier 4a | Tier 4b |
|---|---|---|---|---|---|
| **K5** — early-return `#armPendingSeed` | pass (blind) | **4 fail** `absent` | — | — | — |
| **E1** — `role` listbox → list | **34 fail** | — | pass (miss) | — | — |
| **E2** — `aria-activedescendant` points at a dead id | **9 fail** `dangling` | **4 fail** `dangling` | — | — | — |
| **E3** — `aria-selected="yes"` | pass (miss) | — | **3 fail** `aria-valid-attr-value` | — | — |
| **E5** — remove `#suppressNextCount` (`:1876`) | — | — | — | **1 fail** `polite: 3 results` | — |
| **E6** — remove the disabled row | — | — | — | — | **`todo` passes** |

Every tier is now shown failing on a planted defect and passing without it. The blank cells are not
gaps in the evidence; the *misses* are the point.

**No tier subsumes another, and that is measured rather than assumed.** Tier 1 catches a wrong role
that axe misses entirely (E1); axe catches an invalid attribute value that Tier 1 misses entirely (E3);
Tier 2 catches a mount-order defect both miss (K5); nothing but Tier 4a sees a spurious announcement
(E5); nothing but Tier 4b sees a misleading composed position (E6). E2 is the one overlap — Tier 1 and
Tier 2 both catch a dangling cursor, and both name it `dangling` rather than merely "missing", which is
the distinction that keeps a stale highlight from passing as "no cursor".

**E3 reversed a conclusion.** Tier 3 was first written off because it found nothing — but it found
nothing because it was auditing a trigger and no options (see below). The earlier judgement was
measuring a broken instrument, not axe.

The general lesson is about method: **"this tier found no problems" is not evidence of anything until
the tier has been shown to fail on a planted defect.** Four of the five tiers initially rested on that
non-evidence, and one of them was inert.

**Not covered:** `aria-input-field-name` (a missing accessible name) is in the gated rule set but was
never exercised by a mutation. Tier 3 is validated by E3; that one rule is not.

## What they cost

Measured from the runs, not estimated.

| Tier | Tests | Total | Per test | Share of added QUnit time |
|---|---|---|---|---|
| 1 APG | 64 | 4,209 ms | 66 ms | **75%** |
| 3 axe | 5 | 551 ms | **110 ms** | 10% |
| 4a announcements | 6 | 445 ms | 74 ms | 8% |
| 4b utterances | 6 | 428 ms | 71 ms | 8% |
| 2 system spec | 8 | **19.5 s** | **~2,400 ms** | separate CI lane |

Three rules follow from those numbers.

**A Tier 2 example costs ~35× a QUnit test.** Twenty seconds added to a lane that already runs for
minutes is affordable, but it sets the admission test: put an assertion there only if it genuinely
needs a real browser. The cursor contract does. A structure snapshot that would pass identically in a
rendering test does not.

**Tier 1 is 75% of the added QUnit time**, at roughly 21 tests × 3 variants. Attribute-level checks
like `combobox-role` do not need to run once per variant, and the existing hand-rolled assertions in
`d-select-test.gjs` were never folded into the primitives, so some coverage is duplicated. This is
where cost should come out, and it can come out without losing a distinct assertion.

**axe is the most expensive per test and scales with DOM size**, because `axe.run` walks the tree. Four
variants is fine; spread across many components it would dominate. Cap it deliberately — one open
panel per variant, not every state. This is why MUI enrols specific demos rather than auditing
everything.

**The runtime is not the real expense.** Roughly 5.6 s of QUnit and 20 s of system spec is noise
against the existing 845-test ui-kit run. The expensive part is the dev loop: `--standalone` rebuilds
on every source change and the browser watchdog needs a retry after one, which is what makes *mutation
testing* slow. That is a cost of validating tiers, not of running them — but it is the thing to fix if
mutation testing becomes routine.

## A scoped audit that reaches nothing reports success

Tier 3 shipped auditing `.d-combobox` — the trigger root. The panel is **portaled out of it**
(`d-select.gts:425`: "not the panel, which the overlay portals out"), so the audit reached **zero
options** and reported clean four times over. It was not measuring the widget; it was measuring a
trigger, and a green result was indistinguishable from a green widget.

It went unnoticed because the tier found nothing and finding nothing looked like good news. A mutation
test is what exposed it: an invalid `aria-selected="yes"` on every row produced no violation, which is
impossible for a rule in the gated set unless the rows were never seen.

The audit now covers `[".d-combobox", "#d-menu-portals"]`, and `auditedOptionCount()` plus a guard
test assert the rows are inside the audited scope before any clean result is trusted. **Keep that
guard.** The general rule it encodes: a scoped instrument needs an independent assertion that its
scope is non-empty, because "no violations found" and "nothing examined" are the same output.

The same shape bit twice in this spike — the styleguide probe reported silence when it had attached
before the live regions mounted, and `announcements.js` throws rather than returning an empty log for
exactly that reason. Three instruments, one failure mode.

## Gotchas worth not rediscovering

- **Never `include Playwright::Test::Matchers` in a system spec.** The module derives its names by
  stripping `to_` from every Page/Locator assertion, so Playwright's `to_have_css` arrives as
  `have_css` and **shadows Capybara's**. Every `expect(page).to have_css(...)` in the group then
  fails with `NotImplementedError: Only page and locator assertions are currently implemented`, which
  points nowhere near the include. `have_text` and `have_title` collide the same way. Construct the
  one matcher you want instead.
- `require "playwright/test"` is needed explicitly; `require "playwright"` does not load the shim.
- **`a11yAudit`'s default reporter throws a plain `Error` with no `.violations`.** Parsing the catch
  block gets you formatted prose; use `setCustomReporter` to capture structured results.
- A **fresh worktree has no `tmp/`**, so `bin/qunit --standalone` dies with `Errno::ENOENT` on
  `tmp/test_server_4566.log`. `mkdir -p tmp/pids log` first.
- Styleguide system specs need **`bin/rake assets:precompile:build_plugins`** after `pnpm build` —
  the styleguide is a plugin, so a core build leaves the page empty and every spec fails on a missing
  trigger. Confirm environment problems against a known-good spec before suspecting your own.

## Running them

```bash
# invoke the discourse-qunit skill first, every run
bin/qunit --filter "APG | combobox"        # 64 — the pattern suite
bin/qunit --filter "DSelect announcements" # what the live regions say, and how often
bin/qunit --filter "DSelect utterances"    # what a row says when the cursor lands on it
bin/qunit --filter "DSelect axe floor"     # Tier 3
bin/qunit --filter "ui-kit"                # regression check
bin/qunit --filter "A11y"                  # the shared live-region service, NOT matched by "ui-kit"

bin/rspec plugins/styleguide/spec/system/d_select_a11y_contract_spec.rb
```

## What this still does not cover

Correct markup does not imply correct announcement. K3 was resolved only by reading react-aria's
source, where `useComboBox` announces selection through a live region gated on `isAppleDevice()`
because VoiceOver does not voice `aria-selected` on a combobox option. No tier here detects that
class; it needs a real listen. Real screen-reader CI is not the answer either — both public design
systems that tried it disabled it for exactly combobox/select on stability grounds.
