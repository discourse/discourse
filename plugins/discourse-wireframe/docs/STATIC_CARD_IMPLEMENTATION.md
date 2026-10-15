# Static Card implementation progress

The authoritative contract is [the editor plan](STATIC_CARD_EDITOR_PLAN.md).
This is a clean break; no existing experimental JSON conversion is planned.

## Current slice

- Replaced Card's old variant/color schema with flat content, composition,
  identity, action, appearance and accessibility arguments.
- Reader uses shared BlockImage for feature image and portrait. Identity remains
  an internal rendering region, not a child block. Empty reader regions are omitted.
- Added cross-field completeness validation with declared-field diagnostics.
  Shared FormKit error links reveal disclosures and prefer the rich-text editor
  over its formatting toolbar.
- Base CSS and responsive Beside are implemented; the captured reference and
  stress scenarios pass bounded visual acceptance. The shared d-fit primitive
  handles Beside's effective presentation and DOM order. Layout row coordination
  has shared reader/editor item hooks and real-wrapper geometry tests.
- Shared inspector disclosure/conditional metadata and Card's visibility hints
  are implemented. Removed media-card and wf:cta-card directly, including their
  registrations, old styles/locales and redundant tests; Card covers independent
  feature/portrait markers. Reference fixtures and independent image lifecycle
  coverage are implemented. The user explicitly deferred the Escape investigation
  on 2026-09-09: it is not a blocker for this Card delivery. No Ember patch is
  authorized. Keep the broader suite's known failures visible in the handoff.

## Latest acceptance status

- Final renderer/layout review reproduced two defects: long button labels were
  clipped at narrow allocations, and inactive editor chrome dropped authored
  flex allocation styles. Both focused regressions now pass (seed dx31jCpX).
  The button test also covers doubled text, RTL and an unbroken label; a temporary
  no-wrap/hidden-overflow override fails its text-containment assertion. The
  allocation test checks actual widths/heights before, during and after editing;
  a temporary growth-only override fails its retained-alignment assertion.
  Both overrides were removed. The full Section/Card/Layout file passes 39/39,
  and the editor Card-layout module passes 3/3. Changed-file lint passes after
  splitting an assertion's combined edge checks.
- The remaining inspector/validation findings now have observed failing
  regressions and narrow repairs: explicitly undefined optional targets retain
  their diagnostics, and field-message IDs include the message as well as the
  fields. The core validation/Card batch passes 381/381, with all four named
  custom-diagnostic tests passing in a subsequent focused run (seed dx31jCpX).
  The editor's new same-field diagnostic test passes in the broader plugin run.
  Temporary null-or-undefined and array-index-key implementations each fail the
  stronger regression and have been removed. Two service expectations were
  updated from the old field-only keys; the combined plugin rerun passes
  907/909, with only the palette teardown and in-place Escape regressions failing.
  The ID finding concerns the helper contract, not an established UI crash.
- The complete Card system file passes 20/20 (seed 8186, ten-second settling
  budget), including upload/reload, undo/redo alignment, delayed/failed artwork,
  complete highlights/stress Cards and the RTL/enlarged-text editing flow.
- The 24 complete desktop highlight/stress captures and eight RTL/enlarged-text
  reader/editor captures were opened across Foundation/Horizon and light/dark.
  Card content is contained and readable in those targets. The RTL captures also
  expose cramped image controls in the fixed-width inspector at doubled text
  size; this remains a visual acceptance defect, not a passing editor verdict.
- RTL test setup explicitly overrides root direction because the test stylesheet
  sets LTR. Its geometry assertion excludes only intentionally hidden empty
  fields on unselected Cards. English interface strings remain; this is not full
  localized-application or browser-zoom coverage.
- The enlarged-inspector regression passes separately across 240/300/520px in
  both text directions. Its 24-image Foundation/Horizon light/dark capture run
  passes 5/5; all captures were reviewed. Source labels and Fit/Zoom reflow, but
  the minimum-width action still splits Reposition mid-word. Extending the
  regression to action text reproduced that defect (seed 8186). A scoped padding
  repair passes the focused flow. A weaker no-wrap workaround fails because its
  text overflows the button; that temporary override was removed. Changed CSS
  and all three system-test/page-object files pass lint. The 19-example combined
  run passes after removing the weaker override. The post-padding capture run
  also passes 5/5 (seed 7510), and all 24 images were opened: the image inspector
  passes the bounded visual check in both themes/modes/directions at each width.
- The latest type check still reports the same 46 diagnostic families/count
  recorded in the baseline comparison; neither validation repair introduces a
  diagnostic in its changed implementation file. This is not a zero-error build.
- Added a complete-height wide reference pass for Museum, Meta Above/Below,
  both HubSpot references and Populii, in reader and active editor modes.
  It uses the existing complete-reference viewport helper and verifies each
  Card is entirely in view. The combined 20-example system run passes with no
  failures. The new 48-image visual matrix passes 5/5 (seed 7510); all images
  were opened and pass the bounded complete-reference review. See
  `tmp/wireframe-card-wide-final/compare.html` and the visual-review document.
- Final all-changed-file lint passes: ESLint, Prettier, Stylelint, RuboCop and
  Syntax Tree. `git diff --check` also passes. No dependency patch or lockfile
  change is included.
- Final review identified an alignment instrumentation gap, not a new runtime
  defect. The position-only test now delegates real allocation measurements and
  proves both positive invalidation and zero further reads across eight idle
  frames. Teardown additionally records mutation observation and the exact font
  and captured-load listeners. A temporary per-frame reconciliation plus omitted
  cleanup fails both tests: eight idle reads and fourteen retained observation
  targets. An independent listener-only omission fails both listener-removal
  checks. All temporary changes were removed; the complete Section/Card file
  passes 39/39 (seed dx31jCpX), including both strengthened tests. Changed-file
  ESLint/Prettier and `git diff --check` pass. The draft-model and block-layout
  request suites also pass together: 30 examples, no failures (seed 8186).
- The Escape teardown investigation is deferred and non-blocking by explicit
  user direction. No Ember patch is authorized, and no dependency patch, lockfile
  change or partial production FloatKit workaround is included. The broader
  plugin result remains 907/909, not an all-green suite. The latest bounded
  renderer, validation and layout review found no additional production defects.

## Verification receipts

- Initial eight leaf Card contract tests failed against the old renderer
  (seed dx31jCpX): shared image, heading order, omissions, identities and actions.
- Those eight and two additional toggle/empty-content tests subsequently passed.
- Cross-field validation test was observed failing before implementation and
  then passed in the 13-test run (same seed).
- Beside geometry test initially failed because adaptive and even were identical.
  After implementation, its split/DOM-order checks passed, but narrow assertion
  used a detached element retained across a draft replacement; corrected to
  resolve the current element and wait for fit.
- Wide media clipping assertion compared transformed bounds against untransformed
  scrollHeight. QUnit scales its fixture by 0.5. Corrected to compare clientHeight
  against scrollHeight; this was not evidence of production clipping.
- All 13 leaf Card tests pass with seed dx31jCpX, including corrected geometry.
  The full Section/Card file subsequently passed 31/31 tests, including the
  original Section cases and eight Layout cases (plus the framework self-test).
- Changed-file lint ran: production CSS/templates passed; test assertion findings
  were corrected afterward. Final lint remains required.
- Typecheck completed with errors in untouched core/plugin files, including
  cta-banner's unused suppression and Chat/Events/Gamification block API issues.
  No diagnostic named a changed Card file. Full baseline comparison is not
  complete; no zero-error claim.
- Initial three Layout tests failed before the coordinator existed, then passed:
  unequal widths/scales, independent rows beside a tall span, and Stack release.
- Extended tests exposed missing Row allocation and a non-Card sibling disabling
  alignment. Both were corrected; the full Section/Card file passed 30/31 tests
  with seed dx31jCpX. Position-only moves and observer cleanup passed, including
  zero further Card style writes across eight settled animation frames.
- The remaining failure was Below peers next to a non-stretched Card: an
  ineligible neighbor disabled the whole cohort. Corrected eligibility to exclude
  that neighbor; the full-file rerun passed.
- Added an active-editor Card layout test through the real chrome wrappers.
  It initially failed because the coordinator counted an absolute editor overlay
  as an allocation. Restricting direct allocations to grid cells / flex items
  made the geometry assertions pass. The completed test also passes pointer
  selection and independent feature-image/avatar target assertions.
- Coordinator implementation typecheck reported no new core errors. Existing
  editor chrome diagnostics remain at unchanged numeric geometry assignments.
- Museum/Meta theme fixture and a real-page system flow now pass (seed 8186),
  checking artwork, tall editorial allocation, media seams and editor selection.
  This caught a two-pixel Card overflow: min-height included the content box but
  not its borders. Border-box sizing removed the measured overflow. The editor
  check compares against its content host, excluding intentional chrome borders.
- Initial system captures used stale test-only CSS. The isolated test_0 cache
  was moved to temporary backup directories and regenerated. Do not format JS
  during system tests: the watcher can remove the bundle a running test loaded.
  The first 16 desktop matrix shots were inspected: NEEDS-WORK. Theme identities
  lacked a foreground tint over their image, photo treatments inverted in dark
  mode, and Horizon's inline guide action clipped. Fixture groups also touched,
  and fixture images omitted intrinsic dimensions, producing editor warnings.
- Added browser regressions for inline action containment (220/320/520/888px,
  both directions) and theme/photo treatments. Both failed before the CSS fixes
  and passed afterward (seed dx31jCpX). Palette simulation belongs on the theme
  root: overriding palette variables on a Card does not recompute inherited
  semantic tokens. Full-file run before that fixture correction passed 32/33.
- The real-page test reproduced missing group spacing, then missing image
  dimensions. Layout Stacks now own the inter-group gap, and the fixture supplies
  artwork dimensions. The complete system flow subsequently passed (seed 8186).
  The editor's unresolved-image warning logic was not changed or suppressed.
- Refined desktop matrix completed (5 examples, seed 7510). All 16 captures were
  opened: theme/photo readability, group spacing, dimensions and inline CTA
  containment improved; overall acceptance remains NEEDS-WORK. Row wrapping,
  the fixture's unregistered headphones icon and busy empty editor regions
  still need attention. Captures: `tmp/wireframe-card-screenshots-refined`.
- Row tests reproduced premature wrapping and ignored explicit grow/alignment.
  Card's preferred Row basis is now 16rem; omitted grow allows CSS allocation,
  while explicit grow and align-self are applied on the logical wrapper. The
  full Section/Card file passed 34/34 (seed dx31jCpX), including 3→2+1→1 wrapping
  and non-stretch exclusion. New Row visuals remain to be captured. The placement
  inspector's default-zero Grow display still needs to represent automatic sizing.
- New registration tests failed before group descriptors and all/oneOf predicates
  were supported, then the UI-hint suite passed 23/23. Malformed/recursive shapes,
  unknown siblings and conflicting group descriptors are covered.
- FormKit's nested-disclosure error-focus test failed before the handler opened
  enclosing disclosures. The full form suite subsequently passed 25/25, including
  actual input focus and reduced-motion scrolling. Native keyboard activation
  still needs real-page coverage.
- Inspector tests exposed missing control defaults and snapshot-based visibility.
  The form now seeds a cached default-resolved snapshot and evaluates visibility
  against its live draft. A deliberately weaker snapshot implementation failed
  the toggle test; the final implementation preserves hidden content and passes.
  The test fixture also needed to unregister the cached service before replacing it.
- Card-specific disclosure/visibility tests were observed failing before its hints
  were wired. All seven `inspector metadata` tests now pass (seed dx31jCpX), covering
  independent identity/image controls, whole-card names, alt text and error focus.
- Changed-file lint for the metadata slice passes. Typecheck still fails in the
  existing diagnostic families; the introduced Layout wrapper-argument diagnostic
  is absent after correcting ChildBlockResult.Component's type. Full baseline
  comparison is pending. An earlier whole-plugin run had five other failures in
  staging-service stubs and an outline icon assertion; do not call them pre-existing
  until compared against the baseline.

## Inspector and catalogue continuation

- Custom block validation now accepts `{ message, field? }` diagnostics as well
  as strings. Only declared fields receive focus targets. Unit tests reproduced
  dropped diagnostics, then passed through both edit-time and full layout
  validation; the blocks validation suite passed 322/322 (seed dx31jCpX).
- Friendly inspector messages preserve translated custom instructions. A new
  regression exposed colliding block-level message keys; keys now include the
  message and repeated identical block messages are coalesced. Both named custom
  diagnostic tests passed in the whole-plugin run (seed dx31jCpX).
- FormKit rich-text error navigation failed when a formatting button preceded the
  editor. Prioritizing contenteditable surfaces removed that symptom; the full
  Form suite passed 25/25, including disclosure and reduced-motion tests.
- The real identity editing flow reproduced an empty inspector editor with a
  zero-sized inline hit area. Inspector-only block sizing fixes it without changing
  canvas inline editing. The full keyboard recovery/correction/toggle-retention
  flow passed (seed 8186). Intermediate failures also corrected test selectors:
  direct summary, the exact FormKit field and its standard toggle helper.
- Removed media-card's component, thumbnail, stylesheet, export, locales and old
  test file; removed wf:cta-card and its registration. Card's existing tests cover
  independent empty feature/portrait markers and populated shared images. The
  catalogue regression failed before removal, then passed by name in its focused
  rerun (1/1, seed dx31jCpX). Rebuilding the watcher was necessary because its stale
  module inventory still imported the deleted component.
- Updated Card's theme-adaptive thumbnail to depict media, heading, copy and an
  action. Catalogue/diagnostic changed-file lint passed. Ruby lint passes with its
  cache directed into temporary storage. Final all-changed-file lint remains.
- Expanded the real theme fixture with both HubSpot compositions, Populii's
  even-split/end promo and content-only promos, Meta's Below row, Andela live-data
  placeholders and all-fields-filled Cards. The reader/editor flow passed at
  220/320/480/800px allocations (seed 8186), checking text, identity and action
  containment. An initial test failure used the wrong body-region selector;
  correcting that selector was a fixture repair, not a renderer fix.
- The missing podcast artwork failed a real-page glyph geometry assertion before
  adding headphones to the fixture theme's SVG icon modifier, then passed (1/1,
  seed 8186). No Card-specific icon registration was added to production.
- Expanded desktop Foundation/Horizon light/dark capture run completed (9 examples,
  52 PNGs, seed 7510) under `tmp/wireframe-card-screenshots-expanded`. Five shots
  were inspected; the full matrix is not visually accepted yet. HubSpot's capture
  needs another scroll position to show its complete editorial composition.
- Visual regressions reproduced a title icon occupying its own row and a short
  media badge stretching across the image. A heading flex row and start-aligned
  media badge removed both symptoms. The full Section/Card file passed 36/36
  (seed dx31jCpX), including RTL icons and long badge text at narrow widths.
  Initial RTL failures after the fix retained a replaced test container; using
  a stable outer allocation corrected the test. Updated pixels remain pending.
- Card upload ownership coverage passed in the draft model suite (10/10,
  seed 8186): hiding media/identity retains four independent light/dark sources;
  removing one source leaves the others referenced.
- The named leaf Card lifecycle test passed (1/1, seed dx31jCpX): copy, paste,
  duplicate, independent crop changes, delete and undo/redo preserve rich text,
  metadata, destinations and all four image sources. The initial fixture tried
  registering an already registered Card, then put placement data at the outlet
  root; removing the redundant registration and using a real Layout parent
  corrected those fixture errors. Actual save/reload/import remain pending.
- Placement Grow now distinguishes omitted automatic allocation from an explicit
  zero. Row/Stack schemas no longer invent zero, and the shared stepper shows
  the schema's Auto placeholder. Two real FormKit/placement regressions first
  failed on the misleading zero; a display-only implementation then failed on
  clearing to null. Clearing custom numeric fields to undefined made both pass
  (2/2, seed dx31jCpX), including explicit zero and increment-after-clear.
  Existing standalone numeric callbacks retain their null-on-clear contract.
- The latest typecheck completed with the same diagnostic families recorded
  above; no diagnostic named the changed Layout or stepper files. Full baseline
  comparison remains pending. Changed-file lint for Grow and lifecycle passes.
- Real Card image editing now passes the complete six-example system suite
  (seed 8186): independent feature/portrait crop, Escape rollback and return
  focus, committed crop undo, four distinct uploads through closed controls,
  in-flight progress, and removing feature media without removing portrait
  sources. The upload test's first failure expected an obsolete closed summary
  after removal; matching the actual empty Upload/URL chooser corrected it.
  The post-Grow core Card/Section/Layout run also passed 36/36.
- Removing feature media exposed a whole-Card upload overlay covering identity
  and copy. The real upload/removal flow failed its new media-bounds assertion
  with the whole-block marker restored; removing that marker made this flow pass
  in the next full run. Above/Below geometry also passes in QUnit (2/2, seed
  dx31jCpX), after correcting a fixture missing plugin admin positioning CSS.
  With the fixture corrected, unscaled viewport coordinates failed before the
  overlay converted them into local CSS coordinates. The full run had three
  other failures waiting for editor entry's companion request to settle; those
  timeouts remain under investigation, not counted as passing coverage.
- The empty-feature screenshot matrix passed (5 examples, seed 7510), and all
  four Foundation/Horizon light/dark PNGs were inspected in
  `tmp/wireframe-card-empty-feature-review/compare.html`. The prompt stays in the
  image region in every shot; no overlap with identity remains. Overall visual
  verdict remains NEEDS-WORK: optional empty text creates canvas noise and
  disclosure headings have weak hierarchy in all four captures.
- A real pointer hit-test reproduced the filled feature overlay intercepting a
  selected media identity's name. Card marks media with overlaid content as a
  passive background target, using the existing chrome drop routing. The focused
  regression then passed (1/1, seed 8186). Ordinary feature and portrait markers
  remain separate interactive targets. Direct inline-edit focus is also covered
  in the follow-up suite run.
- The combined Card editor suite now passes 9/9 (seed 8186), including direct
  inline-edit focus, independent cropping and four-source replacement. The three
  editor-entry timeouts from the earlier run did not recur; their cause has not
  been established.
- Draft save/reload passes in the real editor: the saved identity and both crop
  positions return after refresh, while the reader retains the published version.
  An initial test used a slow negative predicate; switching to the page object's
  explicit absence matcher corrected that fixture issue. Export/import and
  publishing still need coverage.
- Optional body/metadata placeholders were visible on unselected Cards. A new
  system regression failed before adding explicit empty-region modifiers, then
  passed through unselected, selected and deselected states (seed 8186). Existing
  editor selection styling reveals the regions; populated reader output is not
  changed. The selected assertion also rules out an always-hidden implementation.
- All four selected-placeholder captures were inspected in
  `tmp/wireframe-card-placeholder-review/compare.html` (5 examples, seed 7510).
  Foundation light/dark and Horizon light/dark all omit the unselected empty
  regions, retain populated metadata and align the row actions. The two nested
  Composition headings still made the inspector ambiguous.
- The Card's outer group is now Media; the shared image's Composition heading
  remains unchanged. Optional disclosure titles use the section heading scale
  and foreground. A width regression also reproduced shrink-wrapped disclosures
  caused by FormKit's start alignment; local stretch makes their boundaries span
  the rail. The combined hierarchy test passes at the actual 240/300/520px rail
  widths (1/1, seed 8186). Color-only styling failed the width check. The test's
  image legend selector was corrected to exclude the adjacent Reset button.
- Inspector width checks now drag the real separator and verify its announced
  width. The earlier CSS-only helper resized the panel without reallocating the
  canvas, so those screenshots were superseded. The pointer-driven matrix passed
  (5 examples, 12 PNGs, seed 7510), and every PNG was inspected. See
  [the visual review](STATIC_CARD_VISUAL_REVIEW.md): desktop grouping passes its
  bounded review; overall Card acceptance remains NEEDS-WORK.
- The real export endpoint and theme-field import round-trip a complete leaf
  Card without changing rich documents, conditions, IDs/classes, explicit false
  and zero values, placement, destinations or four independent image sources.
  Imported upload ownership retains all four references (1/1, seed 8186). This
  required no persistence code changes; browser publishing is still pending.
- Narrow reader geometry passes for Museum, Meta Above/Below, both HubSpot
  references and Populii at a 390px viewport (1/1, seed 8186). Mobile WebKit
  theme captures completed (5 examples, 24 PNGs, seed 7510). Inspecting Foundation
  light and Horizon dark exposed overlapping Champion badges and titles; simple
  containment was insufficient. Pairwise region separation reproduced this in
  the narrow system flow. Behind media now spans two shared grid rows, with its
  badge above the copy and the artwork behind both. The system flow passed after
  the fix. A top-alignment-only implementation failed the longer badge test at
  double text size; the full Card/Section/Layout rerun passed 36/36, including
  both text directions (seed dx31jCpX). All 24 refreshed WebKit screenshots were
  subsequently opened: the badge/title collision is absent in every theme/mode.
  Full lower reference content remains outside these captures; see the visual
  review for per-shot limitations and an inconsistent initial-glyph capture.
- Type baseline comparison completed against an isolated archive of HEAD
  `1186e2130fe5a8d642ff09ac542260f9da0cb221`, with its own dependencies and generated
  declarations. Both trees used the identical frozen lockfile, `pnpm types:generate`
  and `pnpm lint:types`. Both report 46 diagnostics: 1 core CTA banner, 10 Chat,
  6 Events, 11 Gamification and 18 Wireframe. File/code/message families match;
  the inspector-form location shifts with added code, but still targets the same
  didUpdate invocation. No added diagnostic was found. This proves a matching
  failing baseline, not a clean typecheck.
- The combined Card system suite passes 12/12 (seed 8186), including private
  draft reload, explicit publication and refreshed reader identity/crop values.
  The test creates a writable customization component through the UI before
  editing the private draft; creating that component itself materializes its
  initial layout, so it cannot substitute for the later Publish-button assertion.
  Empty hero/sidebar scaffolds triggered two unrelated structural warnings via
  the unchanged container-children rule. The study fixture now supplies explicit
  placeholders in those out-of-scope outlets, and a new Issues-panel test was
  observed failing before that fixture repair and passing afterward.
- This combined run uses `CAPYBARA_DEFAULT_MAX_WAIT_TIME=10`. With the default
  four-second client-settling budget, reopening the large persisted study
  repeatedly timed out on a scroll event. Instrumentation observed two discrete
  scrolls, stable document/Card dimensions and no repeated Card style writes;
  it did not establish the cause of the delay. The ten-second harness override
  completed the flow. `using_wait_time` does not change this harness's global
  client-settling timeout and was removed. No scroll/runtime workaround or
  validation suppression was added to production; all temporary traces are gone.

## Layout implementation contract

Latest acceptance continuation:

- The complete block-layout request suite passes 20/20 (seed 8186), including
  the new Card export/import round-trip and surrounding publish/export endpoints.
- A reversed Row test passes after expanding identity/body text, doubling text
  size and changing spacing tokens, in both LTR and RTL. Restoring the original
  content releases the extra height. Disabling Card alignment makes its seam
  assertion fail, so natural stretch alone does not satisfy the oracle. This
  adds evidence for those transitions, not asynchronous font/image loading.
- The narrow theme matrix is fully reviewed at its original scroll positions.
  The additional lower-reference run passed (5 examples, seed 7510), and all 32
  PNGs were opened. Museum stories, final Meta Above/Below cards, HubSpot
  programmes/roundtables and Populii promos fit across both themes and modes.
  Complete UNBOUND highlights and stress-case bottoms still need their own
  positions. Per-shot boundaries are recorded in the visual review.
- The complete Card/Section/Layout file passes 37/37 (seed dx31jCpX), including
  the reversed Row invalidation and release test. Changed-file lint passed for
  that test and the lower-reference system test/page object.
- A real Tab/Enter flow reaches the body link, visible primary, secondary and
  next whole-card-only link in order, each once. It follows each destination and
  independently clicks the body/secondary links through the stretched target.
  This exposed an invisible focus ring on whole-card-only links: the focused
  empty anchor has no height. The failed screenshot confirms the missing cue.
  Card now draws an inset ring on its existing whole-card overlay; no additional
  anchor or tab stop is introduced. The complete flow passed (1/1, seed 8186),
  and an effective CSSOM override to a clipped outer ring failed the same test.
  The first inline-style challenge did not establish an effective override and
  is not counted as evidence. All temporary overrides and diagnostics are removed.
- Initial keyboard failures were fixture/harness issues, not navigation defects:
  Capybara's request-URI matcher excludes fragments, so assertions now compare
  exact full URLs. Clicking the title through an element-specific actionability
  check rejects the intended stretched anchor; the test now clicks its viewport
  coordinates and asserts the resulting destination. A stale test stylesheet
  omitted the focus repair until only test_0 was moved to a recoverable backup
  under /private/tmp/wireframe-card-focus-css.y7GoPE and regenerated.
  Focus-slice lint and git diff --check pass. The keyboard theme matrix passed
  (5 examples, seed 7510); all four PNGs were opened and show the full inset ring.
  The visual review records this bounded pass separately from overall acceptance.
- After the focus repair, the complete Card system suite passes 14/14
  (seed 8186, ten-second settling budget), including the new keyboard and lower
  reference flows alongside image editing, inspector, draft and publish coverage.
- A real Roboto Mono font becomes available only after the initial Card row has
  settled. The media identity reflows, its peer grows, media seams/actions stay
  aligned and removing the font releases the extra height. This test passed
  with coordination and failed its media-seam assertion with coordination off
  (seed dx31jCpX). Restoring coordination and linting was followed by a full
  38/38 Card/Section/Layout pass. This is late-font evidence, not delayed-artwork
  or editor-undo geometry evidence; no coordinator change was needed.

Remaining acceptance gates after this continuation:

- Complete refreshed desktop reference positions, including UNBOUND highlights
  and all stress-case content; the desktop delayed/failed artwork row is reviewed.
- Full reader/editor RTL, text zoom and image-backed/integrated Section visual
  coverage, beyond the geometry and partial screenshots already recorded.
- Resolve the remaining full-plugin Escape failure; final combined system run,
  lint and code/design review.

Latest lifecycle continuation:

- The four-source upload flow now saves the draft, refreshes the page, reopens
  the editor and verifies the same four distinct source URLs before removing
  only feature media. The first reload assertion compared absolute DOM properties
  with relative attributes; using the same absolute representation corrected the
  test. No source-persistence change was needed.
- Real inspector identity expansion grows all three media stories; toolbar undo
  restores their original height and redo expands them again, with media seams
  and action edges aligned at every step. This and upload/reload pass together
  (2/2, seed 8186).
- The reader artwork test holds an actual request, verifies pending image state
  without losing identity or changing row geometry, resumes it, then repeats with
  a real 404 response and finally a successful reload. Loaded, pending, failed
  and recovered states retain the same media heights and aligned action edges
  (1/1, seed 8186). All eight desktop pending/failed screenshots were subsequently
  opened: identities and copy remain readable with aligned seams/actions in both
  themes and modes. The failed image retains the browser's small broken-image
  indicator. See the bounded visual-review result for scope and image links.
- The full-plugin run reproduced six failures out of 907 (seed dx31jCpX), not
  only the five previously recorded. The staging fixture omitted the image
  composition peer and accidentally instantiated it against a partial mutation
  engine; it now supplies an inactive composition target. The outline test
  expected Section's obsolete image icon; it now compares rendered icons with
  each block's declared metadata. The same-seed rerun passes 906/907, leaving
  Escape-to-exit in the in-place text test. Temporary event tracing identifies
  FloatKit's capture-phase close-on-Escape handler as consuming that event;
  the owner of the open float and the appropriate repair remain under investigation.

### Deferred follow-up: Escape after preview teardown

The user deferred this investigation on 2026-09-09 and explicitly excluded it
from Card delivery blockers. Do not patch Ember. The reproductions below are
integration tests; ordinary live-editor hover, dismissal and subsequent text
editing have not been shown to exhibit the same failure. Investigate that normal
interaction first when this follow-up resumes. Preserve the reproduction tests
separately from the Card commit rather than treating them as a required Card fix.

The remaining Escape failure is reproduced outside the editor by the new core
`re-anchoring a service tooltip releases Escape on teardown` test. Replacing an
open tooltip's options, removing its host and pressing Escape in a fresh input
leaves the input's handler uncalled (seed dx31jCpX). The palette re-anchoring test
now checks the same symptom after teardown.

Lifecycle tracing observed two Escape modifier instances installed and only the
original destroyed. Changing the tooltip's list key or simplifying the conditional
invocation did not resolve it. A static Escape modifier with an enabled argument
passed the focused test, but the broader FloatKit run then failed after 96 passes
when another surviving handler accessed a destroyed tooltip owner. That partial
workaround was removed; production FloatKit files are unchanged.

Inspection of installed ember-source 6.10.1's bundled Glimmer runtime shows that
replacement dynamic modifiers are associated with `UpdateDynamicModifierOpcode`,
but creation of that opcode does not associate it with the view's destroyable
tree. This is a candidate explanation for the observed test-teardown symptom,
not proof of a normal-use editor defect. The proposed dependency repair was
rejected by the user. No dependency patch or lockfile change has been made.

`data-block-layout-item` identifies the direct logical child on both reader and
editor allocation wrappers. The Layout modifier reads only its direct allocation
boxes and the leaf Card regions inside those wrappers; it does not depend on
editor class names. Grid/Row keep their original layout models and source data.

Media's structural pseudo-element exposes its natural CSS sizing preference
independently of synchronized media height. Copy/actions and media identity have
unconstrained natural measurement regions. A Layout-owned ResizeObserver and
mutation invalidation feed one read-then-write animation-frame pass. Dimensions
stay in CSS pixels when the canvas is transformed. Writes are diffed; exclusions
and teardown remove the three transient custom properties.

Broader theme/RTL/zoom, undo/lifecycle and active-editor geometry acceptance is
still pending. Initial geometry passes do not constitute visual acceptance.

## Local development

### CSS conformance review

Reviewed the current Card stylesheet, Layout Card-allocation rule and inspector
stylesheet diff against the repository BEM, responsive and theme-token guidance.
New Card modifiers are standalone, sizes respond to allocated containers,
colors use paired palette/semantic tokens, and
the inspector repair retains existing controls with scoped logical spacing.
The existing Layout modifier names were not renamed as part of Card allocation.
The rich-text editor's existing outer focus-within border is retained.

One deliberate departure from the standard breakpoint mixins remains: the
inspector uses a 10rem content-fit threshold, below the shared scale's smallest
20rem breakpoint. The control must adapt to a narrow rail independently of the
page, including enlarged text; using the page-scale breakpoint would change
ordinary-width behavior. Card's 30rem Beside threshold similarly matches its
existing effective-presentation fit contract. No global breakpoint was added.

This is a CSS design-conformance check only. Aesthetic acceptance remains in the
visual review; full code-structure, behavior, performance and security review
are not established by this check.

Adding the new internal files required restarting this worktree's bin/dev to
refresh the module inventory. Incremental imports alone did not discover them.
Avoid importing the blocks utility barrel from the schema helper: it introduced
a circular initialization failure; import arg-patterns directly.

No commits, site-layout writes or upload deletions have been made in this slice.
