# Shared image editing

Status: Image + Section implementation checkpoint. Shared source controls,
Fill/Fit, free position picking, numeric coordinates, zoom, and canvas adjustment
are implemented in the working tree. Validation is recorded below; the remaining
consumer rollout and responsive/HiDPI upload work are separate milestones.

## Checkpoint implementation

- Core owns `BlockImageValue`, normalized composition, validation, and the
  `BlockImage` clipping-frame renderer. Intrinsic source dimensions remain
  separate from optional `frame` dimensions.
- `DPositionPicker` provides presets, free dragging, and keyboard-accessible
  numeric coordinates; its interactive example is in the styleguide forms section.
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

### Verification receipts (2026-09-07)

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

Build a domain-free UI-kit position picker using the existing pointer-drag
primitive. Compose the shared image-editor body into the inspector and a FloatKit
canvas editor. Keep form integration host-specific to avoid nested forms. Use
FormKit numeric/range controls and DButton actions; add a styleguide example.

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
