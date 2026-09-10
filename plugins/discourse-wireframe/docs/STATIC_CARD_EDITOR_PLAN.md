# Static Card implementation plan

Status: implementation in progress, reviewed 2026-09-09.
This is the authoritative implementation plan. The approved visual target is
[the static Card study](mockups/static-card-study.html). Earlier container and
compatibility proposals are superseded. See
[implementation progress](STATIC_CARD_IMPLEMENTATION.md) for current verification.

## Outcome and boundaries

One static Card choice in the palette and one leaf in the outline. Content,
image, identity and actions are flat arguments, edited without children,
composite parts or detaching. It must produce the approved static examples and
work inside Section, Stack, Row and Grid without routine sizing repair.

The user confirmed these blocks are pre-release: replace APIs and remove
duplicates directly. No migration, conversion classifier, aliases, version flags,
legacy renderer, compatibility-driven fields or deployment inventory. Update
repository-owned examples/tests to the new API. This does not authorize rewriting
a running site's layouts or deleting uploads. Old experimental JSON is unsupported.

Live-data blocks, whole-page/theme recreation, unrelated type errors and the
wider image-consumer overhaul are out of scope. Non-card regions are placeholders
in reference fixtures. Card uses shared image handling in this implementation.

## Catalogue and authoring model

| Block | Decision |
| --- | --- |
| card | Replace schema/renderer with the approved leaf Card. |
| media-card | Remove component, registration, thumbnail, styles and obsolete tests; identity/media coverage moves into Card tests. |
| wf:cta-card | Remove demo composite; content-only Card covers its insertion use case, including two actions. |
| wf:cta-actions | Keep: an independent button group is not a competing Card. Remove documentation tying it to the deleted composite. |
| cta-banner | Keep: dismissal/cookie behavior is a separate task. |
| callout | Keep: semantic notices are different from promotional cards. |
| Live topic/category/member/event/channel blocks | Unchanged. |

No presentation palette variants: the current palette flattens variants into
peer choices. Insert one neutral Card with empty copy; no recipe wizard or preset
infrastructure. Fixtures are configured examples, not extra insertion choices.

Fixed regions match the approved study and simplify editing/alignment. A
container supports arbitrary content but recreates the detach/selection problem
the user rejected. Separate card types have smaller individual forms but restore
choice paralysis. Compatibility scaffolding protects a contract the user has
explicitly released us from.

## Canonical fields and defaults

All argument names below are the new production contract, not compatibility
aliases. Flat fields retain existing rich/image editor targeting. Defaults use
the existing argument resolver, not serializer rewrites. Optional text is empty.

| Group | Fields / type | Defaults and behavior |
| --- | --- | --- |
| Content | title, body: richInline paragraph; meta: richInline plain | Empty; meta remains below title. Preserve rich documents. Empty reader regions occupy no space. |
| Heading | headingLevel: integer 2–6 | 3, independent of visual scale; Advanced control. Empty title emits no reader heading. |
| Label and icon | eyebrow: richInline plain; icon; iconTarget: title/label; iconStyle: plain/tile; labelStyle: plain/badge; labelPlacement: content/media | Empty label/icon; title/plain/plain/content. A label-targeted icon can appear without label text. Media label applies to Behind; otherwise content fallback retains the setting. |
| Image | image: shared BlockImageValue; imageDecorative: boolean; imageAlt: string | No image; true; empty. Informative image requires descriptive alt; no title-as-alt guessing. |
| Composition | presentation: none/above/below/beside/behind; imageWidth: adaptive/even; imageSide: start/end | above/adaptive/start. Replaces variant, no aliases. Missing image yields content-only flow. Changing presentation preserves media data. |
| Identity | identityEnabled; identityName, identityRole: richInline plain; avatar: shared image; avatarDisplay: image/initials/none | false; empty text/avatar; image. Enabled populated identity requires name. Portrait independent from feature image; no invented silhouette. |
| Identity format | identityFormat: compact/feature/stacked; identityPlacement: content/media; identityShape: circle/rounded; identityTreatment: theme/photo | compact/content/circle/theme. Feature means portrait beside name. Stacked means portrait above name. Media placement applies to Above/Below with feature media; otherwise content fallback retains preferences. |
| Primary action | href: URL; actionLabel: string; external: boolean; wholeCard: boolean; linkLabel: string | Empty destination/labels; false/false. linkLabel names a whole-card link without a visible action, never replaces visible copy. |
| Secondary action | secondaryEnabled; secondaryLabel: string; secondaryHref: URL; secondaryExternal | false/empty/empty/false. Independent destination and tab behavior. |
| Actions | actionStyle: link/button; actionLayout: below/inline | link/below. Inline only for content-only at sufficient allocated width; otherwise below. Primary button has stronger emphasis than secondary. |
| Appearance | surface: default/subtle/integrated/accent/contrast; scale: compact/standard/featured; dividers: boolean | default/standard/false. Paired theme surfaces; no raw backgroundColor field. |

Action labels are strings: the action's anchor owns navigation, so embedded link
marks cannot create nested anchors. The plain editor schema disables marks and
breaks at plugins/discourse-wireframe/assets/javascripts/discourse/lib/rich-text.ts:481;
core richInline validation at
frontend/discourse/app/lib/blocks/-internals/validation/args.ts:1340 accepts general
inline documents, not that editor variant. Title/body keep rich capability;
other rich fields render validated runs safely even if raw JSON supplies marks.
Do not nest them inside an action anchor. Add a small core inline-document text
helper for whitespace-aware name/emptiness checks if none exists; never String(doc)
or a dependency on the editor plugin. Test marked/empty documents and hard breaks.

Theme identity and photo identity remain distinct whole-media treatments,
independent of Card surface. Preserve the approved unboxed composition, never a
floating nested profile panel. Theme uses paired tokens; photo uses a readable
overlay/foreground pair. Warm graphics and portraits are authored assets/theme
styling, not sample-specific options. With no feature source, identity falls back
to content; a theme graphic can be supplied as ordinary media.

Default/subtle/accent surfaces use paired theme text and backgrounds; contrast
uses a paired contrasting surface, not literal dark colors. Integrated is
transparent and inherits the surrounding foreground. Expose deliberate CSS custom
properties for theme customization, not an unrestricted color form. Behind owns
its readable overlay/foreground independently of Section. Pixel review must
validate bright/busy artwork and integrated cards on image-backed sections.

## Editor and accessibility contract

Content and Media are immediately available. Media contains presentation and the
shared image control; its nested Composition controls handle fit, position and
zoom. Optional Label/icon, Identity,
Actions and Appearance groups use progressive disclosure. Advanced holds
semantics/accessibility details. Enabled features must remain discoverable.

Keep schema-driven FormKit, existing image/rich fields, ui-kit controls and
FloatKit anchored UI. No Card-name branch in the generic inspector, new form
shell or global input resizing.

Minimum shared metadata changes:

- ui.group retains strings and additionally accepts a descriptor
  { name, label, collapsed }. Stable name identifies the group; label is
  translated; presence of a descriptor opts into disclosure and collapsed
  specifies its initial state. Normalize in schema-to-fields, reject conflicting
  descriptors for one name at registration. Disclosure state is editor-only.
- ui.conditional adds { all: [leaf predicates] }; leaves additionally support
  oneOf alongside existing equals/notEmpty. No recursive expression language or
  callbacks. Validate new shapes and sibling references during registration.
  New leaves use one comparator; do not change existing consumers incidentally.
- Visibility uses FormKit transient draft values with schema defaults for omitted
  args, not stale selection snapshots. Empty groups disappear; collapsed groups
  retain mounted fields where needed for error focus.
- Errored fields override ordinary visibility so they can be reached. Before
  focusing a control, the shared FormKit error-summary handler opens enclosing
  native disclosures. Test keyboard focus and scroll, not only open attributes.
  Respect reduced motion. Group state stays out of saved Card args.

Use existing block validate for cross-field diagnostics:

- A visible primary action requires label and destination. An entered href with
  no action label is allowed only for an enabled, meaningfully named whole-card
  link. Secondary requires label/destination when enabled. Secondary-only is valid.
- Whole-card navigation requires href and an accessible name. A visible primary
  action keeps actionLabel as its name and is itself stretched, not duplicated.
  Optional title context belongs in a description, not a replacement name.
  Only when no action is visible does the single stretched anchor use explicit
  linkLabel, then plain title. No URL-derived compatibility fallback. Hide the
  linkLabel control when a visible action supplies the name; retain its value.
  Test different visible label/title/override values with wholeCard=true. This
  preserves [visible labels in accessible names](https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html).
- Do not emit malformed/nameless reader links, even for invalid draft values.
  Elevate secondary and rich-text links above the stretched target. Do not wrap
  Card in an anchor. External targets get safe rel and independent target flags.
- Enabled populated identity requires name. Empty enabled identity remains an
  editable empty draft and emits no reader shell. Portrait/initials are decorative
  beside that name. Role/avatar-only values yield a field diagnostic.
- A supplied informative feature image needs alt whenever presentation is not
  none. Hidden media retains alt/decorative intent. Do not depend on responsive
  width for validation. Inactive optional data does not cause cross-field
  completeness errors, but malformed supplied types/URLs still fail schema checks.

Feature toggles never clear values. Empty Card remains a leaf with editor
placeholders and no empty reader headings/links/media. Primary and avatar image
targets have independent data-block-arg anchors, including enabled empty slots.
Shared drop/paste routing must reach the intended source.

DOM order follows Above/Below and logical Beside start/end. Identity renders
once in its effective region. Responsive reflow must preserve meaningful reading
and focus order; do not reorder interactive content with CSS alone. Editor
selection, inline editing, drop and crop take precedence over reader navigation.
All labels are translated Sentence case; use standalone BEM modifiers, logical
RTL properties, theme tokens and visible keyboard focus.

## Section, Layout and Card responsibilities

| Owner | Owns | Does not own |
| --- | --- | --- |
| Section | Region surface, foreground context, padding, content width | Card crop or row coordination |
| Layout | Allocation, spans, gap, order, wrapping/stretch, matching-row alignment | Card content or persisted image composition |
| Card | Media/content/identity/actions and their natural sizing | Parent tracks or page width |
| Shared image | Upload/URL, dark source, fit, focal position, zoom | Total Card height |

Use allocated Card width, not viewport width. Above/Below share a bounded media
preference: initially 16:9 capped at 18rem, increased when natural media identity
needs more room. This is a preferred media size, never a total-height cap. Long
content grows; no truncation. Tall editorial cells can give spare height to
media; moving to Stack releases that allocation. Behind uses content-driven
minimum size. Beside provides adaptive narrow media or true 50/50, logical
start/end, and falls back to Above at insufficient allocated width. Preserve all
saved source/fit/crop/zoom/split preferences. Tune numeric thresholds with fixtures,
not sample IDs or hardcoded artwork assumptions.

### Matching card rows

Layout gains cardAlignment: auto/off, default auto. No effect on Stack or
ineligible children; no per-card enrollment checkbox.

Eligible participants are direct logical, stretched Card children with matching
effective Above or matching Below media, in one nonoverlapping visual row.
Exclude mixed-presentation rows, row-spanning editorial cells, non-stretch cards,
and cards inside another authored block. Framework/editor wrappers are
transparent to ownership, not removed from DOM. Unequal widths and column spans
are eligible. A common top coordinate alone is insufficient; account for row
extent, overlap and stretch. Wrapping creates independent cohorts; singleton
rows remain natural.

CSS owns stretch and trailing action placement. Cross-card seams use one bounded
core Layout-owned coordinator, shared by reader/editor. Explicit internal Layout
item identity and Card region hooks resolve logical participants. Add minimal
hooks at render boundaries as needed; core must not know editor class names or
scan arbitrary descendants. This stays inside blocks, not ui-kit or an
application-wide service.

One ResizeObserver per participating Layout observes allocation boxes (including
ineligible siblings needed to detect row extent/overlap) and natural-size
content/media-identity regions. Schedule reconciliation explicitly on Layout
mode, placement, order, visibility, stretch, wrap and cardAlignment changes,
Card effective-presentation changes, and relevant theme/token changes, as well
as insertion/removal. Resize observation alone misses position-only changes;
Grid placement is applied by layout.gts:440. Batch at most once per animation frame. Compute preferred
media from width, CSS tokens and natural identity minimum, not already synchronized
media height. Read natural inputs before writing changed cohort CSS properties.
No reset/read/reapply loop. Clear overrides on exclusion and dispose observers,
listeners and scheduled work at teardown. Never persist measurements.

Natural content size is the sum of unconstrained text/identity/action regions,
their active gaps and base padding, excluding flex growth and previously written
minimums. Keep these inner measurement regions independent of the synchronized
outer box. Different scales can have different padding: coordinate the trailing
action inset to the cohort maximum, adding only transient spare space, and
include that shared inset when calculating the content-region minimum. Removing
alignment restores each Card's own inset. No authored padding is overwritten.

Give matching peers a shared media size and content-region minimum; CSS puts
actions at that region's end with the shared trailing inset. Above/Below seams and action bottom edges match;
matching single-line actions share a baseline. Multiline/two-action groups need
not align every internal baseline. Empty optional regions create no phantom
gaps. One long Card must not inflate unrelated rows.

CSS-only flex/subgrid avoids runtime work but does not share internal Card tracks
through the existing Row flex and reader/editor wrappers. Do not turn Row into
Grid, multiply authored tracks or use display: contents to force it. Prove the
coordinator through real wrappers early; if it cannot meet the ownership/no-loop
contract, redesign that mechanism instead of dropping the accepted alignment.

## Delivery sequence and code anchors

Paths are repository-relative and were opened on 2026-09-09. Re-read when
implementing. New internal helper names can be selected during implementation.

1. **Schema, renderer and initial fixtures.** Replace registration/schema at
   frontend/discourse/app/blocks/builtin/card.gts:61 and renderer at :157,
   its stylesheet and thumbnail. Reuse BlockImage at
   frontend/discourse/app/blocks/block-image.gts:22 and Section image hints at
   frontend/discourse/app/blocks/builtin/section.gts:54. Add schema/rendering tests
   for all five presentations, empty/long content, identity, independent actions,
   heading/alt/link semantics. First fixtures: Museum newsletter/tall curator and
   Meta media row. No compatibility tests.
2. **Real-wrapper alignment proof.** Work from
   frontend/discourse/app/blocks/builtin/layout.gts:684 (Grid :692, flex :705),
   app/assets/stylesheets/common/blocks/_layout.scss:38, reader wrapper
   frontend/discourse/app/lib/blocks/-internals/components/block-layout-wrapper.gts:180,
   and editor chrome at
   plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/chrome/block-chrome.gts:2105.
   Implement/test coordinator + minimal shared item hooks. Preserve drag targeting,
   spans and DOM order. This gate precedes broad inspector expansion.
3. **Shared inspector metadata.** Types at
   frontend/discourse/app/blocks/types.ts:94 and :109; decoration validation at
   frontend/discourse/app/lib/blocks/-internals/validation/block-args.ts:101
   and :173 must both change. Normalize/evaluate at
   plugins/discourse-wireframe/admin/assets/javascripts/discourse/lib/layout/schema-to-fields.ts:258
   and :324; consume in
   plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inspector/inspector-form.gts:153
   and :375. Add disclosure recovery at
   frontend/discourse/app/form-kit/components/fk/errors-summary.gjs:13.
   Block cross-field validate is already supported at
   frontend/discourse/app/blocks/types.ts:441. Test other inspectors unchanged.
4. **Complete editing/lifecycle and fixtures.** Exercise shared image field for
   independent feature image/avatar: closed drop/progress, URL/upload, eligible
   dark variant, replace/delete, crop commit/cancel and Escape/focus. Complete the
   reference matrix below. Keep serializer generic at
   plugins/discourse-wireframe/admin/assets/javascripts/discourse/lib/layout/mutate-layout.ts:1392.
   No conversion on raw JSON, save, export or render.
5. **Catalogue cleanup.** Remove media-card and its export at
   frontend/discourse/app/blocks/builtin/index.ts:50, thumbnail and style import at
   app/assets/stylesheets/common/blocks/_index.scss:27. Remove wf-cta-card and
   import/registration in
   plugins/discourse-wireframe/assets/javascripts/discourse/pre-initializers/register-starter-blocks.ts:4
   and :28. Clean priorities at
   plugins/discourse-wireframe/admin/assets/javascripts/discourse/lib/palette.ts:47,
   obsolete locales/chrome selectors and direct references. Retain useful
   independent-image marker tests as Card tests and generic composite tests with
   purpose-built fixtures. Test one Card in search/quick insert/drag/empty-cell
   paths; no hidden legacy registrations or flattened palette variants (:209).
6. **Final acceptance.** Focused Card/Layout/editor/lifecycle suites, changed-file
   lint, type baseline comparison, real reader/editor theme/width/RTL visual
   review. No publish/PR/site mutations are implied. The implementation is not
   complete until all acceptance evidence below exists.

## Reference coverage and verification

Delivery scope update (2026-09-09): the user deferred the Escape-after-preview
teardown investigation and explicitly made it non-blocking for this Card work.
No Ember patch is authorized. Preserve its reproduction and the broader suite's
known failures in the implementation notes; this does not defer Card crop,
focus or other planned interaction coverage.

| Reference | Static Card acceptance | Placeholders |
| --- | --- | --- |
| Museum, primary | Tall curator + wide exhibition Behind; Above story pair; newsletter icon/dividers; Below/Beside/even-split variants | Hero, discussions, contributors, category data |
| HubSpot dark + light | Champion badge Behind; programme icon tile; newsletter; static promotional card appearance | Queried topics/members |
| Andela | Preserve reference preview; no additional static requirement evidenced | Events, milestones, chat channels |
| Populii | Featured Beside/end promo; small content-only accent/contrast promos | Categories/discussions/header |
| Meta | Aligned Above/Below media rows; approved unboxed compact/feature/stacked identity; theme/photo treatments; inline guide CTA | Topics/events/contributors/footer |
| Everything filled | Long title/body/meta/label, portrait/name/role, both destinations, dark feature image, dividers, featured scale | Stress case, not default; no content clipping to beautify it |

Reader and active editor fixtures must cover approximately 220/320/480/800px
allocated Card widths, 3→2+1→1 wrapping, unequal-width column spans, tall row
spans, overlap, nested Layout/Section, non-stretch, reverse Row, RTL and a narrow
sidebar on a wide viewport. Inspector checks use its actual minimum/default/wide
widths, not only Card widths.

Required evidence:

- Schema and rendering tests for defaults, omissions, false values, rich content,
  inactive-value retention, empty reader regions and invalid partial actions.
- Real DOM geometry assertions for seams/action edges across different scales/
  padding and release, position-only placement/order changes, independent
  row heights, fonts/images loading, changed text/identity/source/presentation,
  theme switching, undo and resize. Instrument no feedback loops, sustained
  read/write churn or leaked observers—not merely that measurement executes.
- Keyboard/pointer tests: one primary tab stop, independent secondary/body links,
  meaningful DOM order, visible focus, editor selection and crop cancellation.
- New-schema insert/duplicate/copy/paste/delete/undo/redo, draft save/reload,
  export/import and published reader output. Full image sources/upload IDs,
  conditions, IDs/classes and parent containerArgs survive. Test upload ownership
  for light/dark feature image and avatar: collection is recursive at
  lib/block_layout_uploads.rb:55.
- discourse-visual-review on actual Foundation/Horizon × light/dark renders,
  including bright/busy artwork, integrated Section surfaces, missing/failed/slow
  images, localized long copy and text zoom. Screenshots cannot prove interaction;
  design-conformance review cannot prove aesthetics.
- Load relevant test skills. Defects require test → observed failure → fix →
  observed pass, plus a plausible weaker implementation challenge. Run
  bin/lint --fix on changed files before handoff. No new type errors; report
  unrelated existing failures separately.

## Readiness

No compatibility decisions remain. Numeric sizing/reflow thresholds are tuned
in the real-wrapper fixture slice, not unresolved product scope. Alignment,
identity treatments and reference coverage cannot be deferred as polish.
The latest revision passed lifecycle/alignment and design-conformance/
accessibility review with no remaining design-changing findings. Corrections
included metadata registration validation, disclosure error-focus recovery,
visible action naming, position-only alignment invalidation and shared action
insets across different padding. Each is included in the implementation gates.

This readiness applies to the plan, not the product: no production renderer,
inspector or coordinator has been implemented or runtime-tested in this planning
pass. The first implementation slice is schema/renderer tests and the real
Museum/Meta fixtures, immediately followed by the real-wrapper alignment proof.
Historical audit/impact documents now point here; the transition-classifier
proposal is explicitly withdrawn.
