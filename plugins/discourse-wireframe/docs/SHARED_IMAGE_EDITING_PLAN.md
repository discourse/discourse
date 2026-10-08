# Shared image editing

Status: Image + Section implementation checkpoint. Shared source controls,
Fill/Fit, free position picking, numeric coordinates, zoom, and canvas adjustment
are implemented in the working tree. Validation is recorded below; the remaining
consumer rollout and responsive/HiDPI upload work are separate milestones.

## Checkpoint implementation

- Core owns `BlockImageValue`, normalized composition, validation, and the
  `BlockImage` clipping-frame renderer. Intrinsic source dimensions remain
  separate from optional `frame` dimensions.
- Wireframe's `ImagePositionPicker` provides presets, free dragging, and
  keyboard-accessible numeric coordinates. Its component, styles, and translations
  belong to the plugin; it continues to use the unchanged core `d-pointer-drag` primitive.
- Composition uses compact property rows: X/Y inputs precede a soft-surface pad,
  Zoom aligns with those inputs, and the slider stretches beneath the controls.
  Numeric controls stay bounded as the inspector widens; the preset dots are
  decorative pseudo-elements inside accessible buttons.
  X/Y labels sit outside the inputs; X, Y, and Zoom retain standard divided
  FormKit after-addons and native FormKit focus styling. The square pad's size
  derives from two input heights plus their gap, aligning its top and bottom
  with the coordinate fields. Numeric widths adapt to the inspector while
  retaining room for three-digit values, and Zoom aligns with the numeric fields
  rather than the external labels. These styles stay local to image composition;
  shared FormKit and the core pointer-drag primitive are unchanged. The approved
  reference is `tmp/inspector-layout-mockups/coordinate-labels.html`, with the
  subsequent pad-height alignment refinement implemented in production.
- Image and Section share full inspector controls and compact floating actions.
  Clicking an image only selects it; the toolbar's Edit image action opens
  Fill/Fit, Reposition, source replacement, and Show image settings. The menu
  anchors to the toolbar button after selection renders, not to the image frame.
  The inspector shortcut waits for the menu to close, then reveals the matching
  source controls; it is omitted when those controls are already visible.
  The popup uses smaller editor text, shared menu-row styling without action
  icons, and an inline Fit setting first, followed by Reposition. A subtle divider
  separates composition from source actions; another precedes the inspector
  shortcut only when it is shown. Composition's full heading, numeric fields,
  and regular buttons remain in the inspector.
  Composition previews are transient; Done or selecting elsewhere commits one
  history entry, while Cancel/Escape restore the original. Save/publish refuse
  active previews.
- Source replacement preserves composition, frame, and the other color-mode
  source. Operation tokens reject superseded results and results after selection
  changes, history navigation, or target removal.
- Menu source actions follow the visible variant: Change light image or Change
  dark image when both exist. A missing dark source exposes Add dark variant
  when the schema permits it. In dark mode without a variant, Change default
  image identifies the source without a repeated fallback note. Uploads capture
  the target variant before asynchronous work begins.
  Fill/Fit and repositioning remain shared and say "Applies to both variants".
- Numeric fields are native labeled controls inside the existing FormKit host;
  the floating editor does not create a nested form. A future shared FormKit
  adapter can consolidate these with other editor numeric controls.
- Browser regressions cover nested-grid sizing, Section bounds, keyboard
  adjustment, pointer dragging without selecting children, and Done/Cancel/Escape.
  Image resizing also checks all eight handle positions, a real corner drag, and
  dimensions retained after changing selection. The handle styles must match
  `DResizeHandles`' standalone direction modifiers (`--nw`, `--n`, etc.).
- Grid-owned images explain their sizing in the inspector's Frame size section.
  Edit grid selects the immediate owning layout, including inside nested grids.
  Grid placement remains on the image's inspector. Independent frame dimensions
  and reset actions are hidden while the grid owns sizing; saved frame values
  are retained for use outside the grid.
- Palette text is non-selectable in the main palette and quick block picker;
  search inputs explicitly retain text selection. Browser coverage exercises a
  native pointer drag over a palette heading and keyboard selection in search,
  alongside the existing native block-drop flows.

The sections below retain the broader approved plan. Other image-bearing blocks,
independent dark crops, responsive candidates, HiDPI feedback, and browser-side
upload optimization are not implemented by this checkpoint. The existing optimizer
still needs the policy and lifecycle investigation described in step 5.

### Inspector close-out verification (2026-09-08)

- Real Arabic-page coverage now uses the site's locale and compiled RTL styles,
  rather than changing only the inspector body's direction. The source dimension
  regression failed with height visually preceding width; a bidirectionally
  isolated width × height value preserves its meaning in both source rows.
- Compiled RTL styles also mirrored the position thumb's centering transform
  and reversed the preset grid. Browser regressions reproduced the displaced
  center/off-center marker and a physical top-left click selecting X=100.
  Local RTL exclusions preserve image-space coordinates without changing the
  surrounding inspector's direction or the core pointer-drag primitive.
- Closing the real upload-error dialog used to clear the selected block and
  destroy the inspector's inline failure feedback. The browser regression
  reproduced this before dialog contents joined the allowed selection scope.
  It now covers pending progress, successful replacement of both variants,
  failure after dismissing the dialog, and empty/default-required state at 240px.
- The image zoom input remains a native range control, with local theme-token
  track/thumb styling instead of browser-selected track colors. A rendered-pixel
  regression failed against the native track and passed with the same subdued
  surface as the position pad. Home/End still update the numeric zoom value.
  Shared FormKit, core range controls, and `d-pointer-drag` are unchanged.
- Longer German labels are supplied through translation overrides on a German
  page. Tabs wrap and the existing segmented-control dropdown fallback fits the
  translated choices without reducing the font size. No layout fix was needed
  for these labels after excluding the deliberately hidden measurement pane
  from the test's visible-content checks.
- Zoom-equivalent checks cover 125% and 200% using a smaller CSS viewport and
  matching device-pixel ratio, with the inspector remaining 240 CSS pixels wide.
  This is emulation, not native browser zoom: keyboard zoom left the headless
  browser's viewport and pixel ratio unchanged, and its settings page could not
  be opened. A manual browser-zoom check remains unverified.
- Screenshot capture previously reset the emulated pixel density. The marker's
  opt-in `preserve_viewport` path now captures through Chromium CDP; existing
  callers retain the usual capture behavior. The zoom regression checks the
  viewport and pixel ratio both before and after capture. Captures are stored
  at CSS-viewport resolution, not presented as native browser-zoom screenshots.
- The 79-test inspector/selection/shared-zoom JavaScript run passed (seed
  `6hMOv27t`), with workspace-scoped core/Wireframe/styleguide types passing.
  The initial JavaScript invocation omitted the plugin target and matched no
  tests; the successful run explicitly targeted `discourse-wireframe`.
- The complete image-editor system suite passed: 17 examples, 0 failures,
  seed `1418`. Targeted ESLint, Prettier, Stylelint, RuboCop, and Syntax Tree
  checks passed, as did `git diff --check`.
- The final Foundation/Horizon × light/dark desktop screenshot run passed:
  17 examples, 0 failures, seed `48524`, with 24 PNGs in
  `tmp/inspector-closeout-final-screenshots/raw/` and its `compare.html` viewer.
  The matrix's single-line marker discovery skips the multiline zoom marker;
  that scenario passed separately with screenshots at both scales in
  `tmp/inspector-closeout-zoom-verified/raw/`.

Visual-review verdict: **PASS for this inspector close-out**, based on reading
all 24 matrix PNGs and the two separate zoom-equivalent captures. This does not
certify native browser zoom, mobile editing, or the surrounding canvas layout
when both rails consume most of the viewport.

Per-state observations apply to each theme/mode variant of
`tmp/inspector-closeout-final-screenshots/raw/desktop-{foundation,horizon}-{light,dark}-wireframe-inspector-closeout-`:

- `uploading.png`: progress remains beside the status in the closed row;
  thumbnail, label, and disclosure stay contained at 240px.
- `error.png`: the selected inspector survives dismissal; warning text wraps
  inside the source row without covering its disclosure or the next section.
- `empty.png`: no dark-variant action precedes the required default image;
  validation and upload target are readable, with Column/Row still paired.
- `long-labels.png`: tabs wrap, Fit switches to a dropdown, and the longer
  reposition action wraps without clipping. Section headings retain hierarchy.
- `arabic.png`: physical top-left remains X=0/Y=0, while labels and surrounding
  layout follow RTL. Dimensions remain width × height. Plugin labels still use
  English fallback; this is not a completed Arabic translation.
- `slider.png`: the track matches the position pad's subdued surface in all
  four variants, including Horizon dark; keyboard focus remains visible.

The separate `desktop-default-light-wireframe-inspector-closeout-zoom-1.25.png`
and `-zoom-2.png` captures retain the compact inspector's aligned inputs and
picker. The shorter effective viewport requires vertical scrolling, and the
canvas becomes heavily constrained with both editor rails open.

### Compact inspector refinement (2026-09-08)

- At the 240px minimum, Fit and Zoom retain inline labels with their controls
  aligned to the inline end. Only Position stacks its label; X/Y remain beside
  the square pad. The slider spans the section without an extra axis indent.
- The reposition action fills the section at narrow/intermediate widths so
  its English label stays on one line. The JSON tab uses the shorter label
  instead of shrinking all tab text. The three English tabs retain normal
  inspector text sizing and fit on one row; longer translations can wrap.
- Inspector segmented controls paint selection on the checked label instead
  of the measured slider. The existing slider measurement updates on value
  changes, not rail resizing, which left the highlight at its previous size.
  This styling is local to Wireframe forms and the shared image Fit control;
  core components, FormKit, and pointer-drag remain unchanged.
- Regressions reproduced stacked compact rows, wrapped tabs, the stale Fit
  highlight, stale grid-alignment highlights, and the intermediate-width action
  before their respective fixes. The final complete image-editor browser suite
  passes all 13 examples (seed `1418`); scoped CSS/Ruby lint passes. The width
  test activates both grid alignment controls before resizing, checking their
  selection alongside Fit and retaining the paired Column/Row assertions.
- This pass changes styles, the translated tab label, browser tests, and this
  record. No TypeScript/JavaScript implementation changed after the preceding
  workspace type check and 65-test inspector JavaScript run.
- Final desktop screenshot matrix: five examples passed (seed `48524`), with
  24 PNGs in `tmp/inspector-compact-final-screenshots/raw/` and a viewer at
  `tmp/inspector-compact-final-screenshots/compare.html`. Captures cover
  240/260/320/480px, inspector RTL, and scrolled grid placement across Foundation
  and Horizon in light/dark mode. RTL here changes the inspector's direction;
  it is not a translated-locale test.
- Visual verdict: PASS for this responsive refinement. The four
  `desktop-{foundation,horizon}-{light,dark}-wireframe-composition-layout-240.png`
  captures show single-row, normal-size tabs, inline Fit/Zoom, contained actions,
  and square pads aligned with the coordinate fields. Their `-placement.png`
  counterparts show paired Column/Row fields and full-width alignment controls
  with correctly positioned selection backgrounds. Foundation dark at 260px
  retains the compact property rows without wrapping the action; Foundation
  light at 320px and Horizon light at 480px preserve bounded numeric controls.
  The Horizon dark `-rtl.png` retains mirrored grouping at 480px. Its bright
  native slider track remains a separate, previously recorded styling issue.

### Initial minimum-width inspector checkpoint (2026-09-08)

- The right rail's actual minimum is 240px. Width coverage now includes that
  minimum alongside 260/320/480px and checks 240/260/480px in inspector RTL.
  The new minimum-width grouping assertion failed before the responsive rules
  and passed afterward (seed `1418`).
- Below 13.25rem of inspector content width, Composition labels stack above
  the controls so the X/Y fields and square pad remain side by side. Source
  thumbnails and gaps shrink locally; tabs wrap and actions stay contained.
  This is a functional checkpoint, not final visual approval: the stacked Fit
  treatment and two-row tabs still need refinement following screenshot feedback.
- Grid placement's Column/Row fields share equal-width columns at every tested
  width. Align/Justify retain separate full-width rows. The layout is scoped to
  the placement form's `grid` namespace; other argument forms are unchanged.
  The pairing assertion failed before implementation, then the complete width
  scenario passed (seed `1418`). Scoped stylesheet/template/Ruby lint passed.
- Workspace-scoped core/Wireframe/styleguide type checking passed. All 65
  inspector JavaScript tests passed (seed `6hMOv27t`); the first attempt could
  not reach the development server and ran no tests.
- The desktop theme matrix passed five examples (seed `48524`), producing
  20 PNGs in `tmp/inspector-minimum-width-screenshots/raw/` and the comparison
  viewer `tmp/inspector-minimum-width-screenshots/compare.html`. Its first run
  timed out during theme compilation, before capturing the editor.
- Visual verdict: NEEDS-WORK for final narrow-width polish. The inspected
  `desktop-foundation-light-wireframe-composition-layout-240.png` and dark
  counterpart show readable three-digit inputs, aligned pad borders, and a
  contained action. The matching Horizon light/dark captures preserve those
  bounds and theme styling. All four still show the indented stacked Fit row
  and two-row tabs under discussion; Horizon dark also retains the previously
  noted bright native slider track. The 480px Foundation light capture retains
  compact property-row grouping. Grid placement is below these captures;
  its pairing is verified by browser geometry, not this visual review.
- Shared FormKit and the core pointer-drag primitive are unchanged.

### Verification receipts (2026-09-07)

- Coordinate-field refinement: spacing and internal-border regressions failed
  before the styling change (seed `1418`); the focus-outline regression also
  failed before moving the ring outside the wrapper. Final desktop matrix:
  five examples passed, seed `54153`, covering 260/320/480px and inspector RTL
  across both themes/color modes. The other 12 image-editor scenarios passed
  in the preceding full-file run. Scoped stylesheet/Ruby lint passed.
  Comparison: `tmp/composition-coordinate-screenshots/compare.html` (16 PNGs).
  Visual verdict: PASS for coordinate-field spacing and focus. In its `raw/`
  directory, `desktop-foundation-light-wireframe-composition-layout-260.png`
  shows all three digits and an uninterrupted whole-field ring;
  `desktop-foundation-dark-wireframe-composition-layout-320.png` shows the wider
  fields with subdued, readable addons;
  `desktop-horizon-light-wireframe-composition-layout-480.png` retains compact
  grouping and theme rounding; and
  `desktop-horizon-dark-wireframe-composition-layout-320.png` retains readable
  field boundaries and a visible accent ring. Shared FormKit and pointer-drag
  were not changed. The existing bright native slider track in Horizon dark
  remains outside this coordinate-field refinement.
- Composition layout and picker ownership: the picker, styles, and translations
  now live in Wireframe; its core styleguide example was removed. Core's
  `d-pointer-drag` is unchanged. Preset buttons draw their decorative dots with
  `::before`, retaining their accessible names and pressed states.
  Geometry regressions failed against the spread-out layout and again when
  narrow labels crowded the controls. The final checks passed at 260/320/480px
  inspector widths and in inspector RTL (seed `1418`). All 13 image-editor
  browser examples passed, as did four focused shared-image QUnit tests (seed
  `xh72Uyix`), changed-file lint, and workspace-scoped core/Wireframe/styleguide
  types. The full type build still reports block-type errors in Chat, Events,
  and Gamification. An accidentally broad Wireframe QUnit run also exposed
  staging-service stub failures involving `registerBeforeHistoryChange`; that
  interrupted run is not a full-suite pass. Full-site RTL and mobile editing
  are not verified by this desktop inspector check.
  The final screenshot matrix passed all five examples (seed `46689`), producing
  16 captures across Foundation/Horizon, light/dark, and the three widths plus
  inspector RTL. Comparison: `tmp/composition-layout-screenshots/compare.html`.
  Visual verdict: PASS for the scoped composition grouping. In that directory's
  `raw/` folder, `desktop-foundation-light-wireframe-composition-layout-480.png`
  keeps the numeric group compact while the slider expands;
  `desktop-foundation-dark-wireframe-composition-layout-260.png` keeps the pad
  beside the inputs with legible labels; and
  `desktop-horizon-light-wireframe-composition-layout-320.png` preserves theme
  rounding and matching slider/picker accents. In
  `desktop-horizon-dark-wireframe-composition-layout-480.png`, those accents also
  match, although the native slider track is visually brighter than the other
  control surfaces—a remaining polish opportunity, not a grouping regression.
- Grouped image menu: the order/divider and redundant-fallback regressions failed
  against the preceding layout (seed `4482`). The new order and visible dividers
  passed across Foundation/Horizon and light/dark (9 screenshot examples, seed
  `33493`). All 9 image-editor browser flows also passed (seed `4482`), including
  dark-source replacement, inspector navigation, and repositioning. Changed-file
  lint and workspace-scoped types passed.
- Click-away repositioning: the browser regression first failed because selecting
  another block discarded the position. JavaScript regressions also rejected a
  simple commit-only fix: it restored focus to the old trigger and added an image
  history entry during block deletion. The final image-lifecycle and block-removal
  run passed all 16 tests (seed `kcKpplBs`), including cancellation, focus retention,
  single-step undo/redo, and safe teardown with a cleared target. Changed-file
  lint and workspace-scoped core, Wireframe, and styleguide types passed.
  All 15 image-editor and palette browser examples passed (seed `4482`), including
  click-away onto another block and non-editor content, Cancel/Escape, dark-source
  upload targeting and inspector focus, and palette text-selection prevention.
- Core image, Section/Card, uploader, and argument validation QUnit suites:
  270 passed, seed `6JhWfYtJ`.
- Wireframe QUnit filter `image`: 44 passed, seed `OJ10Jjaq`.
- Screenshot/browser matrix: 13 examples, zero failures, seed `10559`.
  Desktop editing runs in Foundation/Horizon, light/dark; published rendering
  also runs on mobile. The editor itself remains desktop-only.
- Changed-file lint passes. Workspace-scoped core, Wireframe, and styleguide
  types pass; the full repository build still reports unrelated published-type
  mismatches in Chat, Events, and Gamification.
- Resize regression: failed on stacked handles, then passed after correcting the
  directional CSS selectors (seed `24808`). The resize screenshot matrix passed
  in both desktop themes and color modes (seed `38676`).
- Class-helper cleanup: 50 targeted Wireframe QUnit tests passed (seed
  `8vBAZlYx`), and all three image browser examples passed (seed `43526`).
- Compact image actions and inspector navigation: 113 targeted Wireframe QUnit
  tests passed (seed `HuUDN1mn`). All five image browser flows passed (seed
  `4482`), including real upload replacement preserving fit/frame, explicit menu
  opening, canvas adjustment, inspector focus, and immediate nested-grid selection.
- Desktop screenshot/browser matrix for the compact-menu checkpoint: 21 examples,
  zero failures (seed `16621`), across Foundation/Horizon and light/dark.
- Visual review exposed stale frame summaries and reset actions on grid images.
  The regression failed with both controls present and again with only the
  inspector summary hidden, verifying that the toolbar must follow grid ownership
  too. All five browser flows then passed with both controls suppressed for grid
  images and standalone resizing retained (seed `4482`).
- Final grid-sizing screenshots: five examples, zero failures (seed `2278`),
  covering both desktop themes and color modes. Final changed-file lint and
  `pnpm exec ember-tsc -b frontend/discourse plugins/discourse-wireframe plugins/styleguide`
  passed.
- Popup visual refinement: the inline-fit geometry assertion failed against the
  old layout, then passed across Foundation/Horizon and light/dark (five screenshot
  examples, seed `55610`). It checks that the label and segmented control share a
  row, not merely that the wrapper exists. The same flow covers source replacement,
  Fill/Fit, repositioning, and the inspector shortcut.

### Grouped menu visual check

Verdict: PASS for the reordered menu's grouping, alignment, and light/dark parity.
The screenshot workflow kept this check scoped to the desktop-only editor, with
both an available inspector shortcut and a menu that omits it. Loading/error
states were not recaptured in this layout-only check.

Viewer: `tmp/theme-screenshots/image-menu-grouped/compare.html`.
Each image below is under `tmp/theme-screenshots/image-menu-grouped/raw/`.

| Screenshot | Observation |
| --- | --- |
| `desktop-foundation-light-wireframe-image-compact-menu.png` | Fit leads; two subtle dividers separate the three action groups. |
| `desktop-foundation-dark-wireframe-image-compact-menu.png` | Default-source label is readable without a redundant note; dividers remain visible. |
| `desktop-horizon-light-wireframe-image-compact-menu.png` | Theme rounding is preserved; labels and row spacing remain aligned. |
| `desktop-horizon-dark-wireframe-image-compact-menu.png` | The longer default-source label fits; both dividers retain contrast. |
| `desktop-foundation-light-wireframe-image-compact-menu-variants.png` | Shared-composition hint stays with Fit/Reposition; no trailing divider. |
| `desktop-foundation-dark-wireframe-image-compact-menu-variants.png` | Dark-source action appears below the shared settings, separated by one divider. |
| `desktop-horizon-light-wireframe-image-compact-menu-variants.png` | Compact grouping remains intact with the inspector open. |
| `desktop-horizon-dark-wireframe-image-compact-menu-variants.png` | Hint and action text remain legible, with no empty inspector group. |

The regressions were observed failing before their fixes: duplicate preset
commits, missing alt text, no-op history entries, undo/selection preview cleanup,
partial zoom input, grid-owned image sizing, nested chrome intercepting adjustment
buttons, Section padding overflowing its declared width, and frame resizing using
the source ratio instead of the authored frame ratio.

Visual review verdict: NEEDS-WORK for polish; the tested interaction blockers are
resolved. The shared controls and canvas adjustment are usable at this checkpoint.
Standalone Image captions currently
center across the wider block rather than its narrower explicit image frame.
This pre-existing caption layout is unchanged by the checkpoint. Source-control
spacing and empty/loading/error visual coverage should be revisited during the
remaining consumer rollout.

Focused visual review verdict: PASS for the compact popup and grid-sizing notice
in both desktop themes and color modes. The visual-review skill prompted removal
of the contradictory saved-frame summary and reset actions. Quick actions remain
legible on opaque surfaces, and the notice separates grid sizing from image
composition without duplicating numeric controls. This does not change the
broader polish observations above or claim visual coverage of upload error states.

Captures can be regenerated with
`TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_SUBSET=wireframe-image bin/rspec spec/system/theme_screenshots_spec.rb`.
The comparison viewer is `tmp/theme-screenshots/compare.html`. Under its `raw/`
directory, each filename below has the prefix `desktop-` and suffix
`-wireframe-image-<state>.png`, unless explicitly marked mobile.

| Theme/mode | State | Observation |
| --- | --- | --- |
| foundation-light | controls | Position marker, numbers, and zoom remain legible and aligned. |
| foundation-dark | controls | Inputs and selected marker retain contrast. |
| horizon-light | controls | Controls fit the inspector alongside Horizon button styling. |
| horizon-dark | controls | Selection and input focus remain visible. |
| foundation-light | compact-menu | Unboxed action rows have aligned icons/text; Fit shares a row with its switch. |
| foundation-dark | compact-menu | Action text and selected Fill remain legible; the footer divider stays subtle. |
| horizon-light | compact-menu | Shared menu styling avoids competing pill buttons; the switch retains the theme's shape. |
| horizon-dark | compact-menu | Actions, inline Fit, and the separated inspector shortcut remain clear on the opaque surface. |
| foundation-light | grid-sizing | Frame size notice and Edit grid fit the inspector; stale size summary/reset are absent. |
| foundation-dark | grid-sizing | Notice, supporting text, and Edit grid remain legible on the dark panel. |
| horizon-light | grid-sizing | Help text wraps cleanly above the themed Edit grid button. |
| horizon-dark | grid-sizing | Frame size hierarchy remains clear; no independent size controls compete with the notice. |
| foundation-light | reposition | Done/Cancel stay inside the image frame. |
| foundation-dark | reposition | Opaque action surface separates buttons from the image. |
| horizon-light | reposition | Rounded actions no longer extend under the inspector. |
| horizon-dark | reposition | Frame outline and both actions remain visible. |
| foundation-light | published | Section clips its background; caption-width polish remains. |
| foundation-dark | published | Composition is retained; same caption-width observation. |
| horizon-light | published | Section respects the surrounding theme content bounds. |
| horizon-dark | published | Content stays separate from the transformed image surface. |
| mobile-foundation-light | published | Frames shrink to the viewport; the caption remains visible. |
| mobile-foundation-dark | published | Same responsive layout, with readable foreground text. |
| mobile-horizon-light | published | Grid children stack; the background remains clipped. |
| mobile-horizon-dark | published | Stacked content and caption remain visible without image overflow. |

## Inspector refinement proposal

Status: FormKit addon prerequisite committed as `4949439ecc8`. Shared dimension
fields, image X/Y/Zoom, and independent frame dimensions now adopt its addons.
The source-row and inspector hierarchy pass is implemented and uncommitted.
The contextual menu checkpoint is committed. Review subsequent refinements
visually before widening scope.

Core prerequisite checkpoint (2026-09-07):

- Input controls accept named `before`/`after` blocks, with independent DEBUG
  assertions for argument/block conflicts. `undefined` means absent; empty text
  and `null` conflict with a same-side block.
- Rich addon wrappers omit text-addon padding/borders. Direct native-select and
  button primitives inherit joined corners and height. Narrow-field geometry
  tests cover LTR and RTL containment, matching heights, and a shared border seam.
- The new rendering/assertion tests failed before implementation. Geometry tests
  failed before the stylesheet change. All 211 FormKit tests then passed (seed
  `fl4roCu8`). A temporary truthiness-only assertion failed the empty-string and
  dynamic-conflict cases; the explicit presence checks were restored.
- Final focused run: all 16 input-text/addon tests passed (same seed). Scoped
  `bin/lint --fix` passed, and workspace-scoped core, Wireframe, and styleguide
  type checking exited successfully.
- The core FormKit guide documents ownership of addon labels, disabled state,
  handlers, and values. The styleguide input example includes static percentages
  and a working-unit selector. The anonymous local browser could not access the
  styleguide route, so its visual appearance is not yet verified there.
- No inspector input/event handlers changed in this checkpoint. Next: adopt the
  API in shared dimension controls and image composition without changing draft,
  commit/cancel, or undo boundaries, then implement the approved inspector layout.

Unit-control adoption checkpoint (2026-09-07, not committed):

- Shared dimension controls use a text addon for fixed units and a named addon
  containing `DNativeSelect` for editable units. FormKit label, disabled, error,
  and description bindings are forwarded without nesting another form.
- Image X/Y/Zoom use percent addons. The position picker exposes an input-width
  custom property; composition supplies one width for all three fields. Zoom's
  number is beside its label, with the slider on the following row.
- Native event handlers retain ownership of preview/commit boundaries. The
  input's field adapter does not persist on each keystroke. Dimension values
  remain numbers or CSS strings according to their existing configuration.
- QUnit passed all 59 inspector tests and all 13 shared-image tests (seed
  `rwYQr4fB`). The initial run reproduced missing addons and missing disabled
  bindings. The typing-only test dispatches `input` explicitly: the installed
  `fillIn` helper also dispatches `change`, so it cannot prove that boundary.
  A deliberately weaker binding (disabling only the number/slider, not its unit
  selector) also failed the new host-state test; the full binding was restored.
- Geometry is covered by the real-editor system test, not QUnit, whose page
  does not include plugin admin CSS. The geometry assertion failed against the
  old cached layout and passed after regenerating the test stylesheet manifest.
  All nine image-editor system examples passed (seed `36686`).
- Foundation/Horizon × light/dark desktop captures passed (seed `8402`), with
  the numeric fields sharing widths, heights, and inline edges in each theme.
  Images and comparison viewer: `tmp/inspector-unit-screenshots/compare.html`.
  Visual review: unit alignment passes; overall inspector polish still needs
  work (source-row density, heading rhythm, label weights, and action placement).
  Mobile/RTL editor screenshots were not captured in this checkpoint.
- Workspace-scoped core, Wireframe, and styleguide type checking passed. Local
  typed boundaries remain necessary for the untyped FormKit input/native select.
- A broad plugin run before production edits also found six unrelated failures:
  four staging-service stub failures, one outline icon assertion, and one
  in-place Escape assertion. These were not changed in this pass.

Inspector hierarchy checkpoint (2026-09-07, not committed):

- Default and dark sources are adjacent compact preview disclosures, before
  composition. Populated sources start collapsed; an empty default source starts
  open. Expanding a source reveals the existing Upload/URL chooser and removal
  actions. Upload and URL mutation ownership remains unchanged. A request to show
  dark image settings still expands and focuses that source.
- Composition has an inline Fit row, Reset beside its heading, aligned percent
  inputs, and a full-width zoom slider. Grid-owned frame sizing uses a compact
  notice and Edit grid action. Independent dimensions use FormKit px addons;
  frame reset sits with those dimensions, not source selection.
- Shared inspector tabs say Settings, and field labels use normal sentence case
  and FormKit typography. Only implicit group headings are suppressed; explicitly
  named General and Advanced groups remain. Image's Content group is defined in
  its schema, without an image-specific generic-renderer branch.
- New source/group tests failed against the old implementation. A naive rule
  hiding every General heading was also observed failing the explicit-group test.
  Final inspector run: 62/62 passed, seed `rwYQr4fB`, including composite locks,
  conditional fields, ordinary controls, and existing layout inspector coverage.
- Image browser flows: 9/9 passed, seed `53682`. Screenshot review then exposed
  global details-summary styles stacking source rows. The new geometry test
  failed before the scoped selector repair and passed afterward, seed `60098`.
- Desktop visual review: PASS for the refined image-source/composition layout.
  Foundation and Horizon light/dark shots show horizontal preview rows, aligned
  percent inputs, clear Content grouping, and retained Grid inspector controls.
  All eight Image/Grid PNGs were inspected in
  `tmp/inspector-refinement-screenshots/raw/`; the viewer is
  `tmp/inspector-refinement-screenshots/compare.html` (matrix seed `61643`,
  5 examples, 0 failures). Mobile/RTL and expanded-source screenshots are not
  covered by this capture.
- Workspace core/Wireframe/styleguide type checking and scoped lint passed.

Inspector source-chooser refinement (2026-09-07, not committed):

- Expanded default/dark sources keep the preview in the disclosure header. The
  existing Uppy component supplies a compact upload/drop target without repeating
  the image, lightbox, or Change/Delete toolbar. A common Remove image action is
  available for either source type, including while the URL tab is selected.
- Each disclosure owns its border and expanded content; the chevron reflects its
  open state. Source, composition, and frame spacing uses local tokens. No shared
  uploader defaults, generic form spacing, upload handlers, or URL commit
  boundaries changed.
- The duplicate-preview assertion failed before implementation, then passed in
  the 62-test inspector suite (seed `rwYQr4fB`). Coverage checks both variants and
  removal availability after switching to URL, not just the default upload.
- The real-browser source flow replaces an image through the inspector and
  removes its dark variant while retaining the uploaded default. Foundation and
  Horizon light/dark capture runs passed (5 examples, seed `25909`). All eight
  source-chooser PNGs were inspected in `tmp/inspector-source-screenshots/raw/`;
  the viewer is `tmp/inspector-source-screenshots/compare.html`.
- The complete image-editor browser suite passed all 10 examples (seed `1031`),
  including resize, positioning, contextual menus, inspector focus, and upload.
- Visual verdict: PASS for the desktop source chooser. Each preview appears once,
  the upload target stays compact, and both variants retain matching controls.
  Expanded dark help takes extra vertical space; optional content grouping and
  narrow/RTL editor captures remain separate follow-ups.
- Workspace core/Wireframe/styleguide type checking and scoped lint passed.

Further visual refinements can address optional content-field disclosure. The
current pass keeps link/caption fields visible and retains the existing Metadata
disclosure rather than redesigning its internals.

Inspector feedback pass (2026-09-07, not committed):

- An empty default source exposes Upload/URL immediately, without a disclosure.
  Dark-variant controls appear only once a default exists. Required validation
  follows the default chooser instead of an unavailable dark-variant action.
  Frame size is also hidden for empty grid-owned images; the screenshot review
  caught it separating the chooser from its error, and the expanded empty-grid
  regression failed before that guard was added.
- Closed default/dark rows accept file drops through the shared external-drop
  modifier and existing image-upload service. Each row retains its own target,
  shows pending/failure feedback while closed, and refuses another pending drop.
  Native chooser and URL commit behavior remain unchanged.
- Pending closed rows show an accessible native progress bar beside Uploading.
  It starts indeterminate, follows the uploader's actual percentage events, and
  disappears on completion or failure. Progress subscriptions stop notifying
  consumers after settlement. QUnit coverage checks both variants and multiple
  intermediate percentages, rejecting a static or completion-only bar.
  The updated inspector suite passes 65 tests (seed `rwYQr4fB`); the paused-upload
  screenshot matrix passes 5 examples (seed `7997`) across both desktop themes
  and color modes. Four inspected captures verify the bar stays beside the label
  at a 260px rail width and disappears after success. Comparison:
  `tmp/inspector-upload-progress-screenshots/compare.html`. Workspace types and
  changed-file lint pass. Invalidate the test stylesheet manifest after SCSS
  changes; stale compiled styles initially hid the inline layout in this run.
- Shared inspector forms use 14px-equivalent theme typography, with stronger
  16px-equivalent section headings, consistent field spacing, and separators
  between argument groups and the separate placement form. These rules are
  scoped to the inspector, not global FormKit defaults.
- Image composition uses matching Fit/numeric columns, lighter unit addons,
  and the same heading hierarchy for Composition and Frame size. Source names
  and grid actions no longer compound relative font-size reductions.
- Empty-state, closed-row drop, section-boundary, and font-size assertions were
  observed failing before their respective fixes. The 64-test inspector QUnit
  run passed with seed `rwYQr4fB`, including both variant destinations, visible
  failure state, and rejection of duplicate pending drops. The existing test
  service must be unregistered before installing the upload stub, otherwise
  Ember retains its cached real instance.
- All 13 image-editor browser scenarios passed (seed `1031`), including Image,
  Heading, Paragraph, Button, real closed-row uploads, and narrow-panel/RTL
  geometry. The final theme matrix passed 9 examples (seed `7997`), producing
  32 inspected PNGs in `tmp/inspector-feedback-screenshots/raw/`; comparison:
  `tmp/inspector-feedback-screenshots/compare.html`.
- Workspace core/Wireframe/styleguide type checking, changed-file lint, and
  `git diff --check` passed after the final empty-grid correction.

Visual verdict: **PASS for the desktop LTR feedback scope; NEEDS-WORK for full
RTL polish.** The RTL shots only change the inspector body's direction, not the
site locale or compiled RTL stylesheet. Numeric geometry stays aligned, but
source dimensions reverse reading order and the segmented selection indicator
needs investigation in a real RTL locale. Mobile/touch was not verified here.

Further inspector feedback: wide rails separate the position picker from its
coordinates and spread compact settings across excessive whitespace. Next layout
pass should keep related controls in bounded groups, review section density, and
exercise narrow, default, and wide rails rather than one reference width. The
upload-progress verification does not establish completion of inspector layout.

Per-state observations apply to each `desktop-{foundation,horizon}-{light,dark}`
capture under `tmp/inspector-feedback-screenshots/raw/`:

| Filename suffix | Observation |
| --- | --- |
| `wireframe-inspector-feedback-image.png` | Source names remain readable; Composition and Frame size use matching, stronger headings; numeric edges align. |
| `wireframe-inspector-feedback-placement.png` | Content and Grid placement have visible separators and matching heading sizes; fields fill the same column. |
| `wireframe-inspector-feedback-heading.png` | Text, Icon, Level, and Alignment remain compact; Grid placement is clearly separated. |
| `wireframe-inspector-feedback-paragraph.png` | Rich-text fields retain their toolbar; Stack item has a distinct boundary. |
| `wireframe-inspector-feedback-button.png` | Label/link/style/icon fields share the same spacing; Stack item remains distinct. |
| `wireframe-inspector-feedback-empty.png` | Upload/URL is immediately available; Required directly follows the upload target; dark/frame controls are absent. |
| `wireframe-inspector-feedback-narrow.png` | Position coordinates wrap below the pad without overflowing; X/Y/Zoom remain aligned. |
| `wireframe-inspector-feedback-rtl.png` | Mirrored numeric geometry is contained; source text ordering and segmented indicators are not a full RTL pass. |

Scope constraint: shared inspector changes can affect every block. Shared
structure improvements may ship alongside image-specific refinements when they
benefit other block inspectors too. Identify them explicitly in the proposal,
implement them at the shared owner, and validate their consumers. Candidate
shared improvements include heading hierarchy, group spacing, label styling,
and control alignment; none is approved solely because it improves Image.
Preserve the compact menu presentation and shared uploader defaults. Do not
introduce Image-specific exceptions into generic field wrappers or grouping rules.

Before implementation, map each proposed change to its owning component and its
consumers. Any shared primitive change requires explicit justification and a
regression matrix covering ordinary string/number fields, grouped fields,
conditional fields, composite locks, and grid placement on non-image blocks.
Use existing representative block fixtures rather than treating an Image-only
screenshot as evidence that the shared inspector still works.

First local prototype: `tmp/inspector-refinement/index.html` (not production UI).
It compares Image, Heading, and representative Layout fields. The prototype uses
the local compiled Dracula and light-default palettes and offers a 300px panel
mode. Source selection is simulated: files are not uploaded, URLs are not fetched,
and site data is not changed. Image previews reuse the supplied reference.

Ownership for the implementation review:

- Shared header/tab treatment: `inspector-panel.gts`; changing Args to Settings
  is a proposed wording change, not a new inspector view.
- Shared field-group headings and spacing: `inspector-form.gts`, the field
  wrapper, and inspector-scoped styles. Suppress only redundant unnamed-group
  headings, not meaningful schema groups.
- Source rows and variant selection: `inspector-image-field.gts`, with the
  existing image-upload service retaining ownership of async operations.
- Composition presentation: the full variant of `image-composition-controls.gts`;
  retain the compact contextual-menu variant and composition service behavior.
- Content grouping: Image's schema UI hints, not image-specific branching in the
  generic inspector. Grid placement retains its owning inspector component.

Prototype verification: rendered dark and light at 300px panel width, checked
390px viewport stacking without horizontal overflow, and exercised source-picker
visibility, adding/removing a simulated dark variant, coordinates, zoom, reset,
and Edit grid focus. No prototype script errors were observed. These checks do
not establish production component, theme, upload, or history behavior. Selects
and text choices in the representative panels stand in for existing specialized
controls; replacing those controls is not part of this proposal.

Alignment acceptance criteria (raised during prototype review): X/Y currently
stretch with the position grid while Zoom has its own fixed width. The prototype
therefore passes overflow checks but still has visibly mismatched numeric fields.
Replace these independent sizing rules with a consistent numeric-with-unit layout.
X, Y, and Zoom must share width, height, inline start/end edges, padding, and unit
alignment. Keep space for native number steppers so suffixes do not overlap them
on hover or focus. Labels may vary, but must not determine numeric field widths.
At narrow widths, reflow the position group rather than shrinking one field alone.

Use FormKit's existing input `@after="%"` support for percentage suffixes rather
than custom absolutely positioned spans. The `input-number` field resolves to
the same input control, whose suffix is a separate flex item. Equal outer field
widths remain an inspector layout responsibility. Check compact input/suffix
heights together: the current suffix stylesheet uses `var(--space-9)`.
Integrate through the existing FormKit host without nesting forms, and preserve
composition previews, explicit commit/cancel boundaries, and single-step undo;
FormKit's default input handler calls the field setter on each input event.

Editor-wide unit convention: fixed display units use FormKit's `@after` support,
including existing dimension-field suffixes, not just image percentages. Derive
the unit from the field's schema/configuration. Editable units retain a real unit
selector with consistent adjoining-control styling; do not replace that selector
with static text. Keep stored value types, parsing, conversion behavior, and
commit timing unchanged. Labels should not repeat a visibly suffixed unit, but
accessible names/descriptions must still communicate it. Counts without units
(such as grid rows and columns) remain plain numeric inputs.

Proposed prerequisite: extend FormKit input controls (not FloatKit) with named
`before` and `after` blocks alongside the existing text arguments. Add DEBUG-time
assertions rejecting an argument and a named block supplied for the same side:
`@before` with `<:before>`, or `@after` with `<:after>`. Check argument presence,
not truthiness, so an empty string does not evade the assertion. Resolve each side
independently: `@before` with `<:after>` and `<:before>` with `@after` remain valid.
Retain existing argument-only behavior. Prefix/suffix classes
must account for either content source. This is a general-purpose input addon
API, with no unit parsing or editor-specific behavior in core.

Rich addon containers should accommodate a select or button without inheriting
the text addon's padding and creating nested borders. Preserve standard sizing,
focus indicators, logical-direction layout, and existing text-addon appearance.
Interactive slot contents need their own accessible labels and must respect the
field's disabled state through an explicit, documented consumer contract. Use
existing select/button primitives inside slots; do not introduce a separate unit
control framework as part of the addon API.

Validate the core extension independently: before/after arguments, named blocks,
valid mixed usage, same-side DEBUG assertions (including empty-string arguments),
dynamic addon presence, text/number inputs, keyboard
focus, disabled state, RTL, and compact/default sizing. Add a styleguide example
with fixed text and an interactive addon. Then adopt it in the editor, preserving
numeric drafts and intentional history boundaries when focus moves to a unit
selector. Keep this foundational change separable for extraction to core.

Before fixing the mismatch, add a browser geometry regression and observe it fail
against the prototype/current implementation being changed. Assert aligned field
bounds, not just absence of horizontal overflow. Verify at 300px and normal panel
widths, with one-, two-, and three-digit values, hover/focus states, browser zoom,
and longer translated labels. Apply the same rules to comparable numeric controls
elsewhere in the inspector without forcing long text inputs into compact widths.

- Keep the inspector a persistent form, not a second action menu. Use aligned
  labels, consistent control heights, sentence-case headings, and subtle dividers
  between source, composition, and block-level content/layout fields.
- Consolidate source editing into a compact preview row with Change and a quiet
  Remove action. Keep upload progress and errors visible. Put Upload/URL choices
  inside the source-changing flow instead of keeping them above every preview.
  Reuse the existing upload pipeline; do not restyle the shared uploader globally.
- Keep default and dark sources adjacent, before shared composition. Show an
  Add dark variant action when absent, or a second compact source row when set.
  Identify the source currently displayed without implying that selecting a
  source for editing changes the site's color mode.
- Keep Fit, Position, and Zoom visible. Align Fill/Fit with its label; retain the
  draggable position pad and adjacent numeric coordinates. Put Zoom's label and
  numeric value on one row with the slider below. Move Reset to the composition
  heading and keep Reposition as the principal action for this group.
- Replace the grid-owned frame-size paragraph and full-width button with a short
  status row and Edit grid action. Keep the longer explanation in accessible
  contextual help. For independently sized images, retain width/height controls
  and a clearly scoped size reset, separate from composition reset.
- Keep alt text visible. Organize caption and link with image content fields,
  separate from shared image-source controls. Retain grid placement as its own
  group; do not hard-code Image-only content fields into the shared image field.
- Avoid redundant General/Image heading levels. Use the existing schema-driven
  field grouping and FormKit host. Keep image-specific styles local; apply
  genuinely shared hierarchy and spacing improvements at the inspector level,
  with coverage for other blocks.
- Preserve source replacement, dark-variant targeting, pending-upload guards,
  keyboard access, inspector field reveal, and single-step composition history.
  Verify both Image and Section at narrow inspector widths, in Foundation and
  Horizon, light and dark modes. This proposal's design-conformance check covers
  existing primitives, tokens, translations, and component ownership; rendered
  aesthetics and behavior require implementation-time verification.

## Goal and delivery boundary

Make editing an image feel the same in every block: select the image, adjust its
fit, position, and zoom, and see the same result in the inspector, canvas, preview,
and published page. Keep source resolution separate from displayed frame size so
responsive/HiDPI delivery can be added without another image-model redesign.

The first implementation milestone is Image and Section working end to end on
the shared controls. It is a review checkpoint, not completion of uniform image
support. Adoption across the remaining supported image fields is required before
calling the shared-controls work complete. HiDPI delivery has its own bounded
investigation and follow-up implementation below.

## Interaction contract

Image fields share one editing UI, whether they belong to an Image block, a
Section background, a card, or an avatar. The inspector and canvas image menu
address the same block key and image argument. Media card's avatar and background
are separate targets.

Uniformity means reusing controls and state, not repeating the full inspector in
a popup. Canvas clicks select images without opening a menu. Edit image in the
toolbar exposes quick actions; source URLs, dark variants, numeric coordinates,
zoom, and frame dimensions stay in the inspector. Adding a missing dark source
and replacing the visible source are available as quick upload actions. Show
image settings reveals the matching source controls even when the inspector is
collapsed, on another tab, or scrolled elsewhere.

The common controls are image source (upload or URL, replace, remove), image fit
(Fill / Fit), position, and zoom. Position combines nine preset dots, a freely
draggable marker, and editable X/Y percentages. Pointer and numeric edits update
the canvas and each other. Zoom has a slider and an editable percentage; 100%
means the selected fit without additional magnification.

Reposition on canvas enters an explicit adjustment mode with Done, Cancel, and
Escape. It edits the same position values as the inspector and must not initiate
block dragging or child selection. An inspector gesture is one undo step; a
canvas adjustment session commits its combined changes as one step on Done.

Frame dimensions remain distinct from image composition. Image block dimensions
and aspect ratio describe its frame; Section height and layout belong to Section;
avatar dimensions belong to the owning block. In a grid, the grid can own frame
sizing while image position and zoom remain editable. A natural-ratio image may
have no visible position adjustment on an axis until it is cropped or zoomed.

## Inspected consumers

| Consumer | Current rendering and sizing | Shared-editor requirements |
| --- | --- | --- |
| Image | Light/dark image renderer; display width/height; resize handles outside grid cells; grid sizing overrides intrinsic sizing | Preserve link and caption; separate frame resize from fit/position/zoom; maintain a stable frame across color schemes |
| Section | Light/dark image in an absolute backdrop; standalone nine-position argument; no image resize | Move composition into the shared image field; retain Section height, padding, width, surface, and scrim controls |
| Card | Plain image; vertical image frame is 16:9; horizontal variant sets its own geometry | Honor shared composition and declared dark variant without changing card layout |
| Topic card | CSS background; custom image URL falls back to topic image URL | Retain the topic-image fallback; honor custom image composition and dark variant; define how adjustment of a fallback is persisted |
| Media card background | Absolute CSS background; declares resize support although its renderer does not consume image dimensions | Use background composition controls; do not present image-frame resize as if it resizes this backdrop |
| Media card avatar | Plain image in a fixed circular frame | Independent image target; honor declared dark variant and shared composition |
| Quote avatar | Light/dark image in a fixed circular frame; no image argument marker on its rendered avatar | Add the shared editor entry point without changing avatar dimensions |
| Video poster | Native video poster URL | Share source controls; do not expose composition controls the native poster renderer cannot independently honor |

## Existing inconsistencies to resolve

- `defaultFit` is declared and schema-validated, but the inspected runtime does
  not consume it; fit is currently hard-coded in individual stylesheets.
- Card, Topic card, and Media card avatar allow dark variants in their schemas
  but use only the light URL. Media card background uses a CSS media query,
  whereas Image and Section use the shared color-scheme-aware image component.
- The canvas image menu has Replace and Remove, while the inspector has upload,
  URL, dark variant, and size-reset controls. Both should expose the same shared
  image editor, with quick source actions allowed as shortcuts.
- Image's `fillImageToBlock` action changes display dimensions using contain
  math. It must not compete with a new Fill control whose meaning is cover.
- Canvas replacement writes a fresh image value, while inspector replacement
  preserves the dark variant. Define one replacement policy that retains frame
  and composition settings consistently and keeps upload references intact.

## Implementation direction

### 1. Establish the shared image contract

Starting anchors:

- `frontend/discourse/app/blocks/types.ts:219` — existing image capabilities.
- `frontend/discourse/app/lib/blocks/-internals/validation/args.ts:1409` — image-value validation.
- `lib/block_layout_uploads.rb:55` — recursive upload-reference extraction.

Define a canonical core image-value type consumed by block renderers and editor
code. Retain the source metadata and positive integer upload ID expected by
validation and retention; remove duplicated editor/block approximations. Source
`width`/`height` record intrinsic dimensions and do not change on frame resize.
An optional `frame: { width, height }` records explicit author sizing; absence
means automatic sizing. New uploads start without an explicit frame. Resize
handles set it; Reset frame size removes it. Grid-owned/fixed/background frames
ignore this override. This replaces the existing overloaded display dimensions
and `naturalWidth`/`naturalHeight` aliases; update all constructors, reset/resize
paths, validators, and tests together. No compatibility adapter is required.
Frame and composition belong to the shared image value, not to each light/dark
source. Ignoring a frame override in a grid must not erase it; removing the frame
override must not erase intrinsic source dimensions.

Add image composition to the image value: fit (`cover` / `contain`, labelled
Fill / Fit), position (`x`, `y`, each 0–100%), and zoom (100–250%, with 100% the
unmagnified fit). Defaults are Fill, centered, and 100%. Position uses image/frame
percentage alignment, not a promise to keep a subject centered at all sizes.
Zoom preserves that anchor. No arbitrary CSS values are accepted. Validate finite
bounds and normalize malformed persisted values safely at rendering time too.

Add an explicit composition capability distinct from frame resizing. The shared
renderer and editor must agree on supported capabilities and defaults. Remove
Section's separate position argument once it adopts the new image value.

Initial scope choices: light and dark sources share composition and one frame;
independent dark crops are deferred. Topic-derived fallback images keep their
existing rendering; composition editing initially requires a custom image, with
that requirement visible in the editor. Do not persist an invalid source-less
image object just to hold a fallback's position.

Acceptance: core and workspace plugin types agree; valid values survive a
save/reload; invalid fit, non-finite values, and out-of-range values are covered;
light/dark upload references are preserved.

### 2. Unify editing state and source replacement

Starting anchors:

- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inspector/fields/inspector-image-field.gts:176` — current selection-derived target.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/services/wireframe-image-upload.ts:286` — shared write entry point.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/services/wireframe-mutation-engine.ts:684` — immediate mutation and undo.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/services/wireframe-mutation-engine.ts:731` — explicit before/after commit.

Use an explicit target `{ blockKey, argName, variant }` throughout image editing,
including upload/probe completion. Consolidate source construction and replacement
across inspector, menu, paste, and image-drop overlay paths. Replace only the
selected source metadata, preserving current frame/composition and the unaffected
variant. Clear the old upload ID when replacing an upload with an external URL.
Explicit frame dimensions stay fixed; an auto-sized frame may follow the new
source's natural ratio. Reject stale async results after replacement, removal,
target switch, or editor teardown. Merge valid completions against current data,
not an obsolete snapshot taken at upload start.

Introduce a narrowly scoped image-edit session with immutable snapshots and
transient composition previews. Do not call the committed mutation path on each
pointer movement. Reuse the existing mutation engine for net commits; do not
rewrite the generic history system or coerce image objects into the string-only
in-place edit session.

- Inspector preset selection: one commit.
- Inspector pad or zoom gesture: live preview, one commit on release.
- Numeric fields: preserve the input draft while typing, preview valid values,
  commit on Enter/blur; Escape discards the draft.
- Canvas adjustment: any number of drags/zoom changes share one session; Done
  or clicking away commits one operation to the editor draft, without saving or
  publishing. Cancel/Escape discards the entire session. Clicking away leaves
  focus with the destination; it does not restore focus to the old controls.
- While canvas adjustment is active, inspector presets, numeric fields, zoom,
  and Reset composition for the same image join that session's draft. They must
  not create separate committed edits that Cancel cannot undo.
- Pointer cancellation discards the active gesture. Source replacement, block
  deletion, editor exit, and unmount discard active previews. Deletion publishes
  the removed layout before selection hooks run, so those hooks cannot commit
  an image edit against the outgoing entry.
- Save/Publish while adjusting requires an explicit Done/Cancel decision; never
  silently serialize a transient preview. Undo/redo clears the active preview
  before applying committed history. Leaving and re-entering must not resurrect it.

Acceptance: inspector and canvas stay synchronized; cancelled/unchanged edits
create no undo entries; asynchronous operations cannot write into another image;
draft, published layout, and upload references agree after replacement/removal.
Test first upload followed by replacement separately from author resize followed
by replacement: the former stays automatic, the latter preserves the frame.

### 3. Build shared controls and complete Image + Section

Starting anchors:

- `frontend/discourse/app/ui-kit/modifiers/d-pointer-drag.ts:52` — shared pointer lifecycle.
- `frontend/discourse/app/form-kit/components/fk/control/input.gjs:8` — number/range controls.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/image/image-edit-menu.gts:103` — existing canvas menu.
- `frontend/discourse/app/blocks/builtin/image.gts:104` — caption/link rendering branches.
- `frontend/discourse/app/blocks/builtin/section.gts:72` — background image and separate position.
- `app/assets/stylesheets/common/blocks/_image.scss:54` — existing fit and grid overrides.

Keep the composed position picker in Wireframe, using the existing core
pointer-drag primitive. Compose the shared image-editor body into the inspector
and a FloatKit canvas editor. Keep form integration host-specific to avoid nested
forms. Use FormKit numeric controls and DButton actions.

The shared control order is Source, Composition, then optional Frame sizing.
Composition contains Fill/Fit, the dot square and X/Y fields, zoom slider and
percentage input, Reposition on canvas, and Reset composition. Existing size reset
and resize handles remain frame operations; remove or rename the ambiguous
fill-to-block shortcut so it cannot mean something different from image Fill.
Only show meaningful capabilities, and show source controls when an image is empty.

Accessibility and gestures are part of the control contract:

- Nine named preset buttons, visible focus/selected state, and no falsely selected
  preset for a custom position. The entire square accepts free positioning.
- X/Y number fields are the complete keyboard alternative to two-dimensional
  dragging; do not label the square as a single scalar ARIA slider.
- Add a keyboard-reachable Edit image action for each target, including named
  avatar/background actions in multi-image blocks.
- Prevent release clicks from firing a second preset action. Keep physical image
  X/Y directions consistent in RTL while localizing labels and form layout.
- Canvas adjustment temporarily suspends competing block/grid drag, image-frame
  resize, and child selection. Escape cancels adjustment before dismissing its
  host. Restore focus to the trigger or a surviving block action on close.
- Clean editor-owned preview state on teardown: the shared pointer primitive
  does not send a terminal callback when its element is destroyed.

Introduce shared block-image rendering with a stable clipping frame and common
fit/position/zoom behavior. Reuse the core color-scheme and CDN mechanisms, but
avoid imposing block-specific crop wrappers on unrelated UI-kit image consumers.
Audit attribute forwarding for alt text and composition styles. Captions, links,
and child content must remain outside the transformed image surface. Preserve
grid stretch behavior and a stable frame when light/dark sources have different
ratios. Scope CSS to image frames rather than every picture inside a grid cell.

Acceptance: review actual Image and Section UI at this checkpoint, including
desktop/mobile, light/dark, links/captions, and grid/non-grid frames. Fit, position,
and zoom have identical meanings in both blocks. Source replacement does not
erase composition. Section children do not move when the background is adjusted.

### 4. Adopt across the remaining image fields

Apply the shared renderer and editor to Card, Topic card custom image, Media card
background/avatar, and Quote avatar. Use the consumer table above as the checklist.
Fix the inspected capability/rendering inconsistencies with failing regression
tests first. Give both Media card images independent targets and remove misleading
background frame-resize affordances. Ensure fixed circular frames clip zoomed
avatars correctly. Keep Video posters source-only with the same source controls.

Acceptance: every editable image uses the same labels, controls, target routing,
replacement policy, and history behavior for its supported capabilities. No
Section-only alternate position UI remains. Verify source upload, URL, remove,
replace, empty/error/loading states, dark variants, and publish/reload across the
consumer matrix before considering the uniform-controls work complete.

### 5. HiDPI investigation alongside steps 1–3; delivery as a separate slice

Include browser-side upload optimization in this investigation. It reduces the
file before upload; it does not generate the responsive candidates later served
to readers. Preserve this distinction in both implementation and UI.

The composer installs `UppyMediaOptimization` explicitly through
`frontend/discourse/app/instance-initializers/register-media-optimization-upload-processor.js:26`.
The processor calls the media-optimization worker, which imports WebAssembly
image codecs. Installed `@discourse/jpeg/encode.js` initializes the bundled
MozJPEG WASM encoder; this was verified in the installed package, not inferred
from project documentation.

The base uploader has an opt-in hook before its checksum processor at
`frontend/discourse/app/lib/uppy/uppy-upload.js:367`. Chat explicitly uses that
hook in `plugins/chat/assets/javascripts/discourse/components/chat-composer-uploads.gjs:30`;
docked composer and AI conversation uploads also register the optimizer.
`frontend/discourse/app/components/uppy-image-uploader.gjs:31` does not install
it. Wireframe's service/overlay uploads also do not install it, even though their
upload type is named composer. The upload-type string is not preprocessor wiring.

Proposed reuse direction: opt the shared block-image upload paths into the
existing processor/worker through a shared core integration with explicit policy,
not separate compressor implementations or a blanket change to all uploaders.
First verify the policy and lifecycle against the following cases:

- Composer defaults are a 524288-byte optimization threshold and a 1920-pixel
  width resize threshold/target (`config/site_settings.yml:2801`), not a
  longest-edge cap. Include portrait sources in the policy investigation. These are declared
  defaults, not the running site's effective values. Eligible JPEG/PNG files are
  optimized; other supported format conversions have additional gates.
- A pre-upload resize discards pixels before server derivative generation. Large
  backgrounds, zoom, and 2×/3× displays may need more than the composer default.
  Decide whether block uploads preserve source dimensions while recompressing,
  use a different bounded cap, or allow explicit preservation. Do not adopt the
  composer cap silently; do not claim a new policy parameter already exists.
- Reuse device/memory safeguards, format/animation/transparency handling, and
  allowed-extension checks. The classic composer initializer has additional iOS
  gates; copying another caller's plugin registration alone does not carry them.
- Run optimization before checksum/deduplication. Preserve correct resulting file
  name/type/size and read intrinsic dimensions from the actual uploaded result,
  not from the pre-optimization local file.
- Audit worker ownership across simultaneous composer/editor uploads and composer
  closure. The worker service currently listens to `composer:closed`; an editor
  upload must not hang if that event terminates a shared worker. Confirm error,
  cancellation, teardown, and disabled/unsupported cases complete predictably.
  Require regression coverage before integration: closing the composer settles
  all editor uploads, and simultaneous requests from different uploaders with
  identical file IDs cannot overwrite one another's resolver.
- Show processing progress consistently across picker/drop/paste/replace paths.
  External image URLs are not local files and do not enter this preprocessing path.

Deliver an explicit recommendation for the block-upload resize policy and any
necessary core lifecycle adjustment before wiring the optimizer into uploads.
Keep both changes in the bounded image-upload slice rather than redesigning all
upload infrastructure as a prerequisite for the controls.

Verified reuse points:

- `app/models/optimized_image.rb:35` — optimized-image lookup/generation.
- `app/serializers/upload_serializer.rb:4` — upload response metadata; currently no responsive candidate set.
- `lib/cooked_processor_mixin.rb:533` — existing post-image resolution candidate construction.
- `frontend/discourse/app/ui-kit/d-light-dark-img.gjs:63` — current dark-source selection.
- `frontend/discourse/app/ui-kit/d-cdn-img.gjs:28` — current single-source image output.

Investigation deliverable: trace one managed upload through optimization,
serialization, block persistence, and rendering. Specify where a bounded set of
uncropped resolution candidates is generated and retrieved, how both color-scheme
sources receive them, and how responsive frame size plus zoom informs selection.
Reuse existing optimization/storage mechanisms; do not invoke image generation
on every layout render or globally expand upload serialization without measuring
its impact. Avoid N+1 upload/variant lookups on pages with many image blocks.

The subsequent delivery slice should provide automatic responsive/HiDPI source
selection for managed uploads, with safe CDN/secure URL handling and the original
as fallback while variants are unavailable. External URLs remain single-source
unless a supported source explicitly supplies variants; do not silently download
arbitrary URLs on the server. Preserve animation/vector behavior or fall back to
the original rather than producing an incorrect derivative.

Add quiet resolution feedback based on source pixels versus the effective
fit/zoom scale at the previewed frame size and target density. Do not derive source
resolution from editable frame width/height or claim sharpness at all viewports.
The browser selects the delivered resolution; authors should not have to toggle
HiDPI on each image. A Use at 2× display-size shortcut is deferred and must remain
an Image-frame action if added later.

This investigation is not a promise that responsive delivery is already wired
up: the inspected block rendering path does not currently build resolution
candidates. Scope the backend change after the trace; it need not block review of
the shared-controls milestone.

## Chosen approach and alternatives

Use one shared editor and shared block-image rendering, with explicit per-image
capabilities and a separate frame contract. Section-specific fields would be a
smaller first patch but would repeat UI and behavior in other blocks. Sharing only
the editor while leaving independent rendering is attractive for smaller diffs,
but would retain the currently observed fit/dark-mode inconsistencies. Replacing
the global image primitives wholesale would centralize behavior further but
unnecessarily affect unrelated application images; prefer a block-image adapter.

The session uses existing commit/history machinery with temporary previews. A
global mutation-engine rewrite is not required for these controls.

## Deferred product choices

The proposed starting scope shares composition across light/dark sources, edits
only custom Topic card images, and uses the mockup's 100–250% zoom range. These
are explicit product defaults for review, not technical limitations.

Independent dark crops, mobile-specific artwork/crops, repeating patterns,
custom background sizing, destructive image editing, and a Use at 2× frame
shortcut are follow-ups. Native video poster cropping is also outside this slice.

## Validation

Reproduce existing defects with failing tests before fixing them. Cover shared
position/zoom synchronization, preset and free positioning, bounds, keyboard
editing, cancel and undo, and replacement preservation. Exercise Image with and
without link/caption, inside and outside grids; fixed avatars; backgrounds;
topic fallback images; and both media-card image arguments. Verify light/dark
variants with different intrinsic ratios and desktop/mobile composition.

Test lifecycle through draft save/reload, publish, and draft deletion, including
upload retention after light/dark replacement and source removal. Test aborted
uploads/probes and switching targets during async work. Verify malformed imported
values render safely, and that alt text survives shared-component forwarding.

Run scoped core/plugin TypeScript checks using workspace types, focused QUnit and
Ruby coverage for changed boundaries, and lint the changed files. Read the QUnit
skill before each test invocation. Add regression fixtures that distinguish the
intended behavior from a weaker implementation, including strongly different
source/frame ratios and nested image consumers.

The implementation must pass a `discourse-visual-review` across Foundation and
Horizon, light/dark, desktop/mobile, plus keyboard/touch checks. Plan-time design
conformance does not replace rendered verification. HiDPI delivery needs network
candidate-selection checks at multiple densities, source sizes, fit/zoom levels,
and secure/CDN configurations after its backend scope is defined.

No backwards-compatibility layer is required for this pre-release work. Continue
using workspace Discourse types while developing the branch.
