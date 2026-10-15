# Block editor readiness

Source audit: 2026-09-09, after the leaf Card consolidation (`7a15bec99e9`).

This is an editor/product assessment, not a claim that every block has passed a
fresh visual or interaction audit. Registrations, schemas, renderers, inspector
controls and relevant existing tests were inspected. The palette changes have
their own regression test. Theme-provided blocks and a site's enabled-plugin
configuration are outside this inventory.

## Classification

Palette policy: all non-live-data blocks assessed as Partial are temporarily
hidden: Conditional, List, Link list, Stats, Quote, Icon, Video and Embed.
Live-data blocks remain available regardless of readiness. The previously
deferred CTA banner/actions, Table and Accordion family remain hidden too.
All hidden implementations stay registered; this is not a removal.

- **Decent:** a coherent authoring workflow exists for the block's stated purpose.
  This does not mean finished or visually certified in every container.
- **Partial:** useful implementation, but editing, defaults or layout contracts
  still need refinement. Keep separate from an unimplemented feature.
- **Deferred:** the product model needs a decision before further polish. Hidden
  from insertion, not removed from the registry.
- **Internal:** implementation structure, not an author-facing choice.

## Layout and structure

| Palette name / registered name | Assessment | Evidence and next concern |
| --- | --- | --- |
| Stack / Row / Grid (`layout`) | Decent; strongest foundation | Three insertion intents share one implementation. Dedicated layout inspector, grid editing, per-child placement, alignment, responsive collapse and card-peer alignment. Keep testing nested allocations rather than adding competing width controls to leaves. |
| Section (`section`) | Decent | Grouped surface, background, spacing, content width, height and accessibility controls. Shared image composition. Its responsibility is the outer surface and content area, not card internals. |
| Tabs (`tabs`) | Decent | DTabs, add-panel affordance, editable labels, panel selection, dragging/reordering and automatic layout wrapping. Dedicated editor integration tests exercise these behaviors. |
| Carousel (`carousel`) | Decent but needs layout polish | Dedicated editor paging/selection support and tests, including insertion between slides. `perView` is a fixed numeric choice; assess narrow slides, mixed content and Card peer alignment separately from Row/Grid. |
| Conditional (`head`) | Partial / advanced — hidden | First matching child wins, with ghost explanations for skipped branches. Uses the general conditions workflow; there is no dedicated branch-oriented authoring UI in the block. Worth keeping as an advanced concept, not presenting as ordinary visual layout. |
| Spacer (`spacer`) | Decent for a small utility | One bounded numeric size; renderer applies it in rem to both axes. Needs clearer unit presentation and guidance to prefer parent gap/padding for routine spacing. |
| Divider (`divider`) | Decent for a small utility | Style and color controls for a horizontal rule. Not a general vertical separator; custom color is not an independent light/dark pair. |
| Table (`table`) | Deferred — hidden | Semantic cell renderer, header options and grid-placement metadata exist. A grid of arbitrary blocks is not yet a clearly designed table-authoring experience (row/column operations, cell editing, responsive tables). |
| Accordion (`accordion`) | Deferred — hidden | Currently a generic child container. Its description assumes Accordion items, but it does not declare a child-block allow-list or a purpose-built item creation workflow. |
| Accordion item (`accordion-item`) | Deferred — hidden with Accordion | Separate titled disclosure container; forced open during editing. Offering it independently would leave half the deferred family in the palette. Decide one coherent Accordion insertion/editing model first. |
| Group (`group`) | Internal — already hidden | Transparent grouping implementation, not another competitor to Layout. |
| Merged cell (`layout-merged-cell`) | Internal — already hidden | Structural helper for merged layout cells, not a palette block. |

## Static content, media and actions

| Palette name / registered name | Assessment | Evidence and next concern |
| --- | --- | --- |
| Heading (`heading`) | Decent | Inline and inspector rich text, heading level, icon and alignment. Clear leaf responsibility. |
| Paragraph (`paragraph`) | Decent | Inline and inspector rich text plus alignment. Clear leaf responsibility. |
| Image (`image`) | Decent; strongest media workflow | Upload/URL, dark variant, composition, sizing, alt text, link and caption. Dedicated inspector, canvas-drop and system-test coverage. |
| Card (`card`) | Decent; strongest static-card workflow | One leaf, five media presentations, identity, labels, actions, conditional inspector groups and shared image composition. Layout owns allocation; Card owns its internals. Dedicated rendering, inspector, system and reference-layout coverage exists. |
| Button Link (`button-link`) | Decent | Inline label/icon, URL, style and validation. The palette label itself still needs sentence case. Keep distinct from the deferred composite CTA actions. |
| New topic button (`new-topic-button`) | Decent | Rich label, category picker, tags, title prefill, icon and style. Editing suppresses opening the composer. It has behavior beyond a URL button. |
| Callout (`callout`) | Decent for its narrow purpose | Severity, icon and editable rich message. A semantic notice, not another general-purpose card. |
| Quote (`quote`) | Partial — hidden | Editable rich quote, attribution and role, plus image upload for the avatar. Uses the older light/dark image renderer rather than the shared composition renderer; identity/layout treatment has not received Card's refinement. Keep the semantic quote purpose. |
| List (`list`) | Partial — hidden | Repeatable plain-text items with add/remove/reorder/import and ordered/unordered choice. No rich item editing, nested-list model or inline list editing in its renderer; a new list starts with an empty array. |
| Link list (`link-list`) | Partial — hidden | Repeatable links with labels, descriptions and icons, plus orientation/gap. Nested icon and URL controls fall back to text inputs in the repeatable editor. Starts empty; its horizontal mode also overlaps action-row use cases. |
| Stats (`stats`) | Partial — hidden | Repeatable value/label/icon/link items, columns and gap. Same nested-control limitations; starts empty. Its stylesheet imposes two columns below its container threshold, so the responsive policy deserves explicit review. |
| Icon (`icon`) | Partial — hidden | Icon picker, size, color and optional link exist. No authored accessible-name argument for an icon-only link; decorative versus meaningful icon behavior needs a decision. This is a source-level gap, not a freshly run accessibility test. |
| Video (`video`) | Partial — hidden | Direct-file URL, poster upload and playback toggles. No video-upload or provider-resolution workflow; poster uses its URL directly. Needs deliberate empty/error presentation and sizing within layout cells. |
| Embed (`embed`) | Partial / developer-oriented — hidden | Accepts author-supplied HTML via a code control. It is not a paste-a-URL/provider picker despite the broad name; arbitrary snippets have no shared sizing contract. Decide whether to expose an advanced HTML block or build a guided embed experience. |
| CTA banner (`cta-banner`) | Deferred — hidden | Rich title/body, button and dismissal configuration exist, but the distinction from Section/Card and dismissal authoring need product decisions. |
| CTA actions (`wf:cta-actions`) | Deferred — hidden | Demonstration composite of two button links with a locked primary style. Structural changes require detaching; it is not a complete action-group editor. |

## Live-data blocks

These remain separate from static Card consolidation. A sensible renderer and
data source do not imply a finished editor, but their live behavior is a reason
to preserve their data contracts rather than replace them with copied text.

| Palette name / registered name | Assessment | Evidence and next concern |
| --- | --- | --- |
| Topic list (`recent-topics`) | Decent basic configuration; partial presentation | Count/filter/category/tag/solved controls and footer link validation. Renderer uses a topic list; needs the same narrow/wide/Section acceptance pass as other data blocks. |
| Topic highlights (`featured-topics`) | Decent basic configuration; catalogue overlap | Similar filter/category/tag controls, same topic-list source, compact presentation. Candidate to combine with Topic list as a presentation choice, but count/filter differences need an explicit contract. No combination is approved here. |
| Topic card (`topic-card`) | Partial | Proper topic picker, image override, excerpt and unavailable-state options. Any image suppresses the excerpt, and its background renderer reads the light URL directly. Does not yet share static Card's presentation, image or peer-alignment contract. |
| Featured categories (`featured-categories`) | Decent basic configuration; partial layout | Category picker and description/footer controls. Owns an internal category grid; collection spacing/columns and interaction with outer Section/Layout need review. |
| Featured tags (`featured-tags`) | Decent basic configuration | Title, count and popular/alphabetical sorting. This is a query result, not a hand-picked tag collection. |
| Top contributors (`featured-users`) | Decent basic configuration; partial presentation | Title, count, period and metric controls. Directory-based metrics are different from Gamification scores; similar appearance alone is not a reason to merge data models. |
| Recently awarded badges (`featured-badges`) | Partial | Count/window controls, but badge selection is a pipe-separated ID string rather than a badge picker. It is an award-recipient feed, not a general badge showcase. |
| Category banner (`category-banner`) | Partial / context-dependent | Logo/icon/description toggles; content comes from the current category route. Needs explicit editor guidance when inserted outside that context. |
| Tag banner (`tag-banner`) | Partial / context-dependent | Description toggle; content comes from the current tag route. Same preview-context problem. |
| Chat channel (`chat:channel-card`) | Partial; plugin-dependent | Numeric channel ID rather than a channel picker, optional membership control. Audit permissions, empty states and editor-safe actions in the dedicated Chat pass. |
| Featured chat channels (`chat:featured-channels`) | Partial; plugin-dependent | Pipe-separated channel IDs, browse footer and membership controls; internal grid. Needs a real multi-picker and an outer-layout contract. |
| Upcoming events (`events:upcoming-events`) | Partial; plugin-dependent | Count/window/category controls exist. Time formatting is a raw format string, title derives from external settings/context, and presentation is a compact list rather than an event-card collection. |
| Gamification leaderboard (`gamification:leaderboard`) | Partial; plugin-dependent | Period/count/display controls exist, but choosing a leaderboard uses a numeric ID. Missing dedicated palette thumbnail and needs editor/presentation validation with the plugin enabled. |

Plugin blocks above are supplied by their respective pre-initializers. Their
availability depends on installed/enabled plugins; this is not a claim that all
appear on the current site's palette. Events also lacks a dedicated thumbnail.

## Highest-value follow-ups

1. Finish the shared repeatable editor before polishing List, Link list and Stats
   individually: real field controls, validation, empty-state guidance and clear
   item-level editing/reordering. Then decide which collection blocks deserve to
   remain distinct.
2. Complete image-consumer consistency for Quote, Video poster and Topic card.
   Separate this from changing the data model or adding new card choices.
3. Give live-data collections a dedicated catalogue/layout pass: Topic list versus
   Topic highlights, Topic card presentation, collection grids, loading/empty/error
   states and category/tag preview context.
4. Keep CTA banner/actions, Table and the Accordion family parked until their
   authoring models are agreed. Do not spend time polishing their current schemas
   just because renderers exist.

For every pass, test a narrow cell inside a wide page, ordinary Stack, wrapping
Row, regular/spanning Grid and nested Section surfaces. Container width, not only
viewport width, should govern adaptation. Outer allocation belongs to Layout;
Section owns surface and content width; leaves own internal composition.

## Source map

- [Core registrations and block sources](../../../frontend/discourse/app/blocks/builtin/index.ts).
  Table rows above identify each source by registered name; `head` and `group`
  live in `block-head.gts` and `block-group.gts`; merged cells live in `layout.gts`.
- [Shared palette builder](../admin/assets/javascripts/discourse/lib/palette.ts)
  filters `paletteHidden` for panel, quick insertion and empty/grid pickers.
- [Repeatable editor](../admin/assets/javascripts/discourse/components/editor/inspector/fields/inspector-repeatable-field.gts)
  currently specializes toggle, number and select; other nested controls use text.
- [Top-level field renderer](../admin/assets/javascripts/discourse/components/editor/inspector/fields/inspector-field.gts)
  has the richer control dispatch the repeatable editor does not reuse.
- [Card argument schema](../../../frontend/discourse/app/blocks/-internals/card-args.ts),
  [Card implementation notes](STATIC_CARD_IMPLEMENTATION.md) and
  [Card visual review](STATIC_CARD_VISUAL_REVIEW.md).
- [Tabs editor tests](../test/javascripts/integration/components/chrome/block-tabs-add-test.gjs),
  [Carousel editor tests](../test/javascripts/integration/components/chrome/block-carousel-editor-test.gjs),
  [Image system tests](../spec/system/edit_wireframe_images_spec.rb),
  [Card system tests](../spec/system/edit_wireframe_cards_spec.rb).
- [Chat blocks](../../chat/assets/javascripts/discourse/blocks),
  [Events block](../../discourse-events/assets/javascripts/discourse/blocks/upcoming-events.gjs),
  [Gamification block](../../discourse-gamification/assets/javascripts/discourse/blocks/gamification-leaderboard.gjs).

The earlier [static-card catalogue audit](CARD_AND_BLOCK_CATALOGUE_AUDIT.md) is
design history; use this inventory for current editor-readiness classifications.

## Verification for the palette deferral

The new palette test was observed failing before the flags were added, including
a separate failure for the Accordion item. Extending the regression to the eight
non-live-data partials failed on List before their flags were added. The final
palette-panel run passed 19/19 tests (seed `I1GLByoV`), including the regression
and positive checks for partial live-data blocks. It checks retained block
registrations, the shared insertion catalogue, rendered palette entries, search,
and previously recorded recent choices; Card and individual buttons remain
available. These assertions also reject deleting the registrations or hiding only
the sidebar rows while leaving the shared catalogue unchanged.

Scoped code lint passed. The repository type build still reports 46 errors in
the existing CTA banner, Chat, Events, Gamification and Wireframe areas; it is
not a green type gate. Type cleanup and the separate Escape investigation remain
deferred, and neither was changed as part of this palette request.
