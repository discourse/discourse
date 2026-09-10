# Card and block catalogue audit

Current entry point: [Static Card implementation plan](STATIC_CARD_EDITOR_PLAN.md).
This audit is design history. Later leaf-card, identity and clean-break decisions
supersede conflicting proposals below; no backward compatibility is required.

Date: 2026-09-08. Source baseline: `1186e2130fe`.

Status: product recommendations for discussion, not an approved implementation
plan. No runtime code was changed. Type-error cleanup and the remaining image
consumer migration are parked while this catalogue decision is discussed.

Implementation draft: [Static Card editor plan](STATIC_CARD_EDITOR_PLAN.md).
The study's visual direction is accepted. The container proposal below was
subsequently rejected in favor of a leaf Card; see
[Leaf Card: mockup goal impact](STATIC_CARD_LEAF_IMPACT.md) for that historical
assessment. The implementation plan contains the final coverage requirements.

Discussion scope clarified by the user: **static, author-written cards only**.
The wider catalogue and live-data observations below are background inventory,
not proposed work for this slice. Do not combine, redesign or migrate live-data
blocks as part of this static-card discussion.

## Scope and evidence

Inspected core block registrations, the Wireframe palette builder and category
ordering, the two Wireframe starter composites, and the Events, Gamification,
and Chat block registrations. Read the card-related schemas, renderers, styles,
data sources, and relevant existing test descriptions. The broader inventory
below also considers the non-card blocks' declared purpose and composition.

This is a source-level catalogue audit, not a fresh browser verification or a
complete correctness review of every block. Installed theme-specific blocks and
the exact enabled-plugin palette on a live site were not inspected. Existing
tests were not rerun. Listed limitations are source observations or design gaps,
not newly reproduced runtime regressions.

Reference priority:

1. Museum: split hero; discussions beside newsletter/contributors; an asymmetric
   editorial grid with portrait and landscape overlays plus image-above cards;
   compact icon-and-description category navigation.
2. HubSpot light/dark: the same broad structure, champion spotlight, a programme
   promotion, topic-backed editorial cards, category links, announcement, footer.
3. Andela: centred hero, event cards, topics, member/badge celebration, channels.
4. Populii: welcome/search banner, promotional hero, illustrated categories,
   compact promotions, discussions.
5. Meta: personalised welcome/search, category links, discussions and sidebar
   widgets, media promotions, CTA strip, footer.

Reference screenshots describe desired outcomes. They do not establish the
implementation or data source used by those sites.

## Decision rule

A separate block earns its place through a distinct author task, content/data
contract, semantic structure, or behaviour. A visual treatment, marketing name,
or sample composition alone should normally be a preset or presentation option.

Keep these axes separate:

- **Content:** author-written content versus a selected topic or queried list.
- **Presentation:** image above, image beside, image behind, or no image.
- **Arrangement:** one item versus a collection; grid position belongs to Layout.
- **Behaviour:** navigation, composer action, dismissal, membership, playback.

Reducing block registrations is not sufficient if the same alternatives remain
equally prominent in the palette or become an overwhelming inspector.

## Principal findings

1. **Manual card choices overlap but have incompatible capabilities.**
   `card` supplies title/meta/body, an image or icon, vertical/horizontal layout,
   and a whole-card link. `media-card` supplies identity, badge, title, background
   and one CTA, but no body field; badge/title/CTA are required. `wf:cta-card`
   supplies heading/paragraph/two buttons as composed parts. A user has to know
   these implementation differences before choosing an apparently similar card.
   Sources: `frontend/discourse/app/blocks/builtin/{card,media-card}.gts` and
   `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-cta-card.gts`.

2. **There is no general child-containing Card block among those choices.**
   Core Card and Media card are fixed-field renderers. The CTA composite has
   predetermined parts. This matters for the museum newsletter's icon, heading,
   dividers, body and action, and for a framed live-data widget. Section can hold
   children, but its page-region width/padding/background contract is not a
   substitute for a deliberate card surface and content structure.

3. **Topic card ties presentation to the presence of an image.**
   Its image is always a background with an overlay; an excerpt is rendered only
   when no image is available. The existing test explicitly expects no excerpt
   for an image card. The museum's image-above stories and image-backed feature
   with supporting copy need presentation and excerpt visibility to be separate.
   This is a product change to an intentional current contract, not an assertion
   that its existing tests fail. Source: `builtin/topic-card.gts` and
   `frontend/discourse/tests/integration/components/block-topic-card-test.gjs`.

4. **Topic list and Topic highlights differ mainly in presentation.**
   `recent-topics` uses BasicTopicList; `featured-topics` renders compact
   title/category/age rows. Both use `topicListDataSource` and the same filter
   enum. They differ in count limits/defaults, and only Topic list exposes solved
   filtering. Neither is a visual collection of Topic cards. Combining these
   needs an explicit supported-filter contract, not just a registration rename.

5. **Live-data cards must not be reduced to manually copied text.**
   Topic card resolves selected IDs with a batched source and viewer-filtered
   responses. Categories resolve category models. Contributors use directory
   metrics; Gamification uses a different leaderboard source. Chat includes
   membership actions. Their data and behaviour earn dedicated contracts even
   when they share card styling. Preserve those boundaries and plugin ownership.

6. **The palette currently exposes implementation variants as peer choices.**
   `CATEGORY_LEADS.actions` puts Card, Media card, CTA card, CTA banner and CTA
   actions together. The starter registration calls the latter composites
   demonstrations, but they are registered without palette hiding. Furthermore,
   `buildBlockPalette` flattens `paletteVariants` into separate rows. Merely
   declaring four Card variants would not deliver one Card choice with a small
   contextual style chooser. Source: Wireframe `lib/palette.ts` and
   `pre-initializers/register-starter-blocks.ts`.

## Recommended card model

### One author-written Card family

Evolve Card into a bounded, composable surface with sensible starter content.
Use existing editable content/action blocks rather than expanding its schema to
include every podcast/person/newsletter field. Keep selecting, moving and
duplicating the card simple while allowing its content to be edited directly.
The exact child/slot/part contract needs a separate design before implementation.

Its responsibilities:

- Surface, border, radius and padding through a small consistent set of choices.
- A defined media/content relationship: above, beside, behind, or absent.
- Shared image composition; frame proportions independent of source dimensions.
- A deliberate foreground/scrim treatment for over-image content in either theme.
- Optional one-destination whole-card navigation; explicit actions when it has
  multiple destinations or interactive content.
- Predictable intrinsic sizing, stretched-grid sizing and narrow-container reflow.

It should not own page maximum width, section/viewport height policy, a grid's
columns, or every live-data query. Those belong to Section, Layout or data blocks.

Offer one **Card** entry with a good default and a few visual starting points
inside its insertion/settings flow. A preset supplies structure and defaults,
not a new block type. Candidate starting points: simple content, image above,
image beside, image overlay. Newsletter, spotlight and media-promotion recipes
can be curated examples rather than permanent top-level choices.

Do not replace the current confusion with a compulsory multi-stage wizard or
four new globally listed card tiles. Searching for newsletter, promo, media or
spotlight should lead to the relevant Card starting point.

### Layout interaction and out-of-the-box quality

The user explicitly requires cards to look good in most ordinary placements
without manual sizing or styling repair. This is a design acceptance criterion,
not a later polish phase. Mockups must show cards inside their actual containing
layouts, not only isolated ideal-sized examples.

Source observations: Layout already establishes inline-size containment and
offers Stack, wrapping Row, and Grid with per-cell stretch/alignment. Its default
responsive rules collapse Row/Grid based on layout width. Grid has an outer cell
wrapper, so card sizing must work through the entire wrapper chain. Current Card
uses a fixed 16:9 top image or 40%-width side image and `min-height: 100%`;
Media card uses `min-height: max(220px, 100%)`. These are existing implementation
choices, not the approved sizing contract for the replacement.

Proposed behaviour to validate:

| Placement | Expected default behaviour |
| --- | --- |
| Stack | Use available width under stretch alignment; height follows content and media. Do not retain an artificial tall-grid height after moving here. |
| Row | Cooperate with parent width distribution, wrapping and cross-axis alignment. Do not force the row wider through image intrinsic dimensions or unbreakable text. Respect explicit non-stretch alignment. |
| Regular Grid | Fill a stretched cell; shared media proportions and bottom-aligned action regions make comparable sibling cards coherent despite different copy lengths. Do not force unrelated rows to equal heights. |
| Spanning/editorial Grid | Fill the assigned tall/wide area while preserving image composition and readable content. Extra height should have a deliberate destination, not stretch typography or controls. |
| Narrow card in a wide page | Adapt to the card's allocated width, not just the viewport or outer grid width. Image-beside may stack above content using a predictable responsive rule. |
| Nested layout or responsive collapse | Recalculate intrinsic sizing through wrappers and return to a natural vertical reading order without stale spans/heights or clipped actions. |

Responsibility boundary: Layout owns the allocation of space between items;
Card owns the composition within its allocation. Avoid competing card width/
height controls when the parent already governs those dimensions. If the real
wrapper/default sizing contract cannot support this cleanly, propose a bounded
shared-layout adjustment explicitly instead of hiding it in a card-specific
workaround. This audit does not authorise such implementation changes.

Media proportions should describe the media region, not lock the height of a
text-containing card. Image-above cards get a useful default media ratio;
overlay cards get a useful preferred minimum height but allow copy to increase
their content requirement. Empty optional content should not leave reserved
gaps. Short copy should not stretch into oversized text or controls. Long titles,
translated actions and missing images must remain usable without author repair.
Do not silently truncate authored text or shrink its font to preserve a mockup.

Keep responsive behaviour understandable: resize changes arrangement, not the
chosen source, copy, crop values or authored presentation setting. Do not guess
a new card type from whether a photo happens to be portrait or landscape.
Pathological explicit constraints, such as a fixed-height cell smaller than its
content, need a defined editor overflow treatment; no default can make arbitrary
constraints attractive. Ordinary auto-sized layouts should avoid that conflict.

Mockup/verification matrix: each static Card starting point in Stack, Row and
Grid; equal and mixed spans; short/long/missing content; portrait/landscape/no
image; narrow/default/wide allocated widths; nested layouts; stretch and
non-stretch placement; live resize and responsive collapse; light/dark and RTL.
Use the same sample card across contexts so differences in behaviour are visible.
The museum's mixed-height editorial grid is the primary composition test.

### Section interaction

The user also explicitly requires Card to work well within Section. Treat the
three roles as one composition contract:

- Section owns the page-region surface/background, outer padding, content-width
  limit and region-level vertical positioning.
- Layout owns arrangement, gaps, relative widths, spans and item alignment.
- Card owns its bounded surface, internal padding, media and content composition.

A Section may directly contain one Card; a separate Layout should not be
mandatory for that case. For multiple arranged cards, the ordinary structure is
Section -> Layout -> Cards. A nested layout must still measure the width left
after Section padding/content limits. Neither Layout nor Card should reintroduce
an independent page maximum width or section-sized outer margins.

Surface defaults must be evaluated on default, subtle and accent Section
backgrounds, as well as image-backed sections, in both color modes. The default
Card should provide its own readable foreground/background pair and enough edge
definition to remain recognisable. It must not accidentally become transparent
or inherit an unsuitable text color merely because its Section changed. A
deliberate transparent/integrated treatment can be available, but it is not the
automatic fallback on arbitrary background photography. Card image overlays
need their own foreground/scrim policy; Section's scrim is a separate layer and
must not be mistaken for sufficient card-content contrast.

Spacing belongs to the boundary it describes: Section padding around the group,
Layout gap between cards, Card padding around its own content. Do not add the
same outer gutter at all three levels. Theme-aware defaults should make this
combination coherent without per-instance compensation.

A tall or vertically centred Section should position the card group, not force
each card to the Section's height. Cards stretch only where the containing layout
actually allocates that space. Selection, image-drop targets and resize/crop
controls must distinguish Section background from Card media and must not obscure
or intercept editable nested content. Shared image controls do not imply shared
image state between those targets.

Add full-section mockups: a lone newsletter card; a regular card grid on a subtle
surface; the museum's editorial mosaic; cards on an image-backed Section; narrow
content-width sections and nested layouts; a tall centred Section. Verify
contrast, total gutters, content sizing and selection hierarchy together.

### Live-data boundary (outside this discussion)

Selecting a live topic is meaningfully different from writing a promotion.
Keep **Topic card** in Community, with the same visual choices as Card where
appropriate, backed by shared rendering pieces. Preserve automatic title/link/
category/excerpt and image fallback; do not make the author configure a generic
data-binding system. Distinguish source-owned text from editable overrides.

A live list is also not a collection of independently authored cards. Keep its
ordering, loading/error/empty handling and querying as collection behaviour.
Share presentation internally without flattening these data boundaries.

## Catalogue disposition

These are proposed product destinations, not changes already made.

### Cards, actions and card-like content

| Current choice / registration | Recommendation | Reason |
| --- | --- | --- |
| Card / `card` | Keep and redesign as the composable Card family | Default author-written card and bounded content surface. |
| Media card / `media-card` | Merge into Card; remove independent public registration after replacement | A media/person promotion is content and styling, not playback or a distinct data source. Preserve identity/badge capability through composition. |
| CTA card / `wf:cta-card` | Replace with a Card recipe; remove production demo registration | Heading, paragraph and actions already exist as reusable content. Keep composite test fixtures independent of the product catalogue. |
| CTA actions / `wf:cta-actions` | Replace with Row + actions recipe; remove production demo registration | Two button defaults and a locked primary style do not warrant another everyday block. |
| Topic card / `topic-card` | Keep; share card presentation | One selected live topic, including fallback and unavailable behaviour. |
| CTA banner / `cta-banner` | Narrow and rename to Announcement | Persistent dismissal earns a behaviour-specific block. Ordinary promotional strips become Card/Section compositions, not a second generic CTA system. |
| Callout / `callout` | Keep under text, not cards | A short toned notice has a clear purpose; it is not a promotion or interactive notification system. |
| Link list / `link-list` | Keep as navigation; optionally rename Links | Repeated destinations, including footer/navigation lists. Do not turn it into another full card designer. |
| Button Link / `button-link` | Keep action capability; simplify label to Button | Navigation is a core building piece. A plain text-link visual style would help the reference CTAs; current variants are primary/default/danger. |
| New topic button / `new-topic-button` | Preserve action; optionally group under Button insertion later | Composer launch/prefill is not equivalent to an ordinary href. Palette grouping can change without collapsing the runtime contract. |
| Quote / `quote` | Keep | Quotation/attribution semantics; can be placed on a Card surface if needed. |
| Stats / `stats` | Keep outside Card | A repeated value/label structure, currently manually authored, not a generic live-analytics block. |

### Community content (background inventory, deferred)

| Current choice / registration | Recommendation | Reason |
| --- | --- | --- |
| Topic list / `recent-topics` | Keep as Topics | Default full list; filter selects latest/hot/etc. |
| Topic highlights / `featured-topics` | Merge into Topics as compact presentation | Same query family; remove the misleading separate highlights choice. Do not silently lose solved/filter capabilities. |
| Featured categories / `featured-categories` | Keep; simplify to Categories and improve presentation | Selected live categories are a real task; compact and descriptive cards should be options, not more block names. |
| Top contributors / `featured-users` | Keep and complete metric presentation | Directory ranking, not Gamification score. Add metric display and optional header/footer treatment. |
| Featured tags / `featured-tags` | Keep; simplify to Tags | Live tag navigation, popular/alphabetical. |
| Recently awarded badges / `featured-badges` | Keep as a specialist Community choice | Recent badge grants are a distinct feed, not a static badge card or contributor ranking. |
| Category banner / `category-banner` | Keep but surface contextually | Current-category context, logo, description and subcategories; not a manual homepage hero. |
| Tag banner / `tag-banner` | Keep but surface contextually | Current-tag context, not an authored promotion. |
| Chat channel / `chat:channel-card` | Retain single-channel capability; group with Channels in the palette | Useful when placing one channel independently. Preserve join/leave behaviour. |
| Featured chat channels / `chat:featured-channels` | Keep as Channels collection | Curated ordered selection, batched fetch and collection layout. Single/multiple insertion choices can share discovery without losing these contracts. |
| Upcoming events / `events:upcoming-events` | Keep in Events plugin; add card presentation later | Current implementation is a compact list, not Andela's image/date cards. |
| Gamification leaderboard / `gamification:leaderboard` | Keep, with clearly identified scoring source | Different data/permissions/plugin availability from directory-based contributors. Share suitable row/frame UI, not an assumed interchangeable score. |

### Structure and basic content (background inventory)

| Current choices / registrations | Recommendation | Reason |
| --- | --- | --- |
| Section / `section` | Keep | Page region, bounded inner width, padding and background. Hero is a composition, not a competing base block. |
| Stack, Row, Grid / `layout` variants | Keep | Their spatial operations are recognisable; one underlying contract already exists. No new editorial-mosaic block is needed. |
| Conditional / `head` | Keep as advanced/contextual | First-matching child selection is real behaviour, not styling. |
| Group / `group`; merged cell | Keep hidden/internal | Structural machinery, not everyday visual choices. |
| Tabs / `tabs` | Keep | Distinct navigation and panel behaviour. |
| Accordion / `accordion` | Keep as an insertion family | Familiar collapsible content structure. |
| Accordion item / `accordion-item` | Remove from general top-level choice; offer inside Accordion/contextually | It is a structural child; do not delete its disclosure capability. |
| Carousel / `carousel` | Keep, lower priority for these references | Scroll/paging behaviour is different from a static grid of cards. |
| Table / `table` | Keep | Semantic tabular content, not a substitute for layout grid. |
| Spacer / `spacer` | De-emphasise, not remove in this slice | Prefer parent gap/padding, but intentional isolated spacing is still different. |
| Divider / `divider` | Keep | Visible content separation, including newsletter composition. |
| Heading, Paragraph, List / `heading`, `paragraph`, `list` | Keep | Foundational content and semantics. |
| Image / `image` | Keep | Standalone meaningful media; shared composition remains the image contract. |
| Icon / `icon` | Keep | Reusable decoration/navigation content. |
| Video / `video` | Keep | Actual file playback, unlike a media-promotion Card. |
| Embed / `embed` | Keep as advanced | Currently accepts pre-cooked HTML, not a URL-to-embed workflow; do not present it as a simple video-link field. |

## Museum layout capability map

| Reference region | Proposed authoring route | Current limitation / work |
| --- | --- | --- |
| Split exhibition hero | Section + Grid/Row + Heading/Text + image + actions | Existing structural route. Typography/brand treatment and artwork are separate from card taxonomy. |
| Latest discussions | Topics, full presentation | Existing BasicTopicList route; align optional heading/footer/action and frame styling with the page. |
| Newsletter | Simple Card with icon, title, separators, text and action | Current fixed-field Card cannot contain that block composition. A signup link does not provide an email subscription backend. |
| Top contributors | Contributors with metric, icon/title and view-all treatment | Current renderer only outputs avatar and username, despite querying a ranking metric. |
| Tall curator feature | Overlay Card; portrait media, bottom-aligned copy/action | Current Media card has no description/body field and a fixed identity/badge scheme. |
| Wide exhibition feature | Overlay Card, or Topic card if backed by a topic | Current Topic card suppresses excerpt when it has an image; manual content needs the new Card composition. |
| Two small editorial stories | Image-above Card or Topic card | Topic card lacks this presentation. Manual Card lacks a visible CTA field and places meta below title. |
| Explore the museum | Categories, compact descriptive presentation | Description currently switches category cards to vertical. The internal grid has a 270px minimum track; no author layout/density selector. CategoryCard uses icon/emoji/square rather than category uploaded artwork. |

The editorial mosaic itself is Layout: a tall left item, a wide upper-right
item, and two smaller lower-right items. Card owns its internal media/content;
Layout owns spans and order. Verify narrow reflow without relying on fixed
desktop heights or visually reordered reading order.

## Other references: distinct remaining needs

- **HubSpot:** largely the same Card/Topics/Categories/Contributors families.
  The top dismissible strip justifies Announcement. Champion and programme
  promotions are recipes. Background gradients, branding and footer arrangement
  do not justify more card types.
- **Andela:** Events needs an image/date-card presentation. Channels already
  has a collection route. The globe with distributed member/badge labels is a
  specialised visualisation, not something the current badge-list renderer or
  generic Card can reproduce by changing padding. A conventional celebration
  list/grid could be an initial similarity compromise, not a claim of parity.
- **Populii:** the page structure is composable, but illustrated category cards
  need an artwork-capable category presentation. The existing category renderer
  does not consume uploaded category logos. Search is not supplied by Card.
- **Meta:** existing topic, Events and Gamification families cover the data
  roles. Watch/listen promotions are Card recipes, not video players. Search/AI
  search and personalised welcome text need their own integrations; no dedicated
  search or welcome block appears in the inspected registrations. Site chrome,
  sidebar/header customisation and exact branding are separate scope.

## Shared implementation constraints to retain

- Common card presentation does not mean a single generic data-query block or
  conversion of live records into copied strings. Preserve source batching,
  viewer access, loading/empty/error states and plugin enablement boundaries.
- Reuse BlockImage for card media and the existing image editor contract.
  Only Image and Section currently opt into `allowComposition`; the card
  renderers still have distinct image handling. Settle the Card model before
  migrating image handling into a Media card slated for removal.
- Build author controls with FormKit and existing UI-kit controls; anchored
  pickers belong to FloatKit. Keep new presentation code block-specific unless
  it has a genuinely domain-independent reuse case.
- Use theme-aware surface/foreground tokens. Current Card takes a raw hex
  background; Media card uses OS dark preference for its backdrop, while Card
  and Topic card read only the default image URL. An image overlay needs a
  paired foreground/scrim policy, not merely `var(--secondary)` text over a
  hardcoded dark scrim in both color schemes.
- Whole-card navigation must not wrap arbitrary child actions in an anchor or
  steal their pointer/keyboard interaction. The existing stretched-link helper
  is a reuse point, not evidence that every composed-child case is already safe.
- Shared frames for data widgets should avoid double borders, duplicated
  headings and repeated view-all links. Prefer sensible defaults with optional
  framing; do not require authors to build every stock widget from primitives.
- All new labels/preset names must be translatable, sentence case, and have
  meaningful thumbnails. Do not add more peer choices solely to show thumbnails.

## Recommended next discussion and delivery boundary

Agree first on one composable manual Card and which existing static choices
become recipes. Live Topic card, topic lists, categories, contributors and other
data-backed blocks are outside this decision. Preserve Announcement's dismissal
behaviour separately from ordinary static promotions.

Then mock up **one Card insertion/inspector model**, with examples of the museum
newsletter, portrait overlay and image-above story at narrow and wide widths.
The mockup must demonstrate changing presentation without re-entering content,
editing child content without a large field matrix, and unambiguous image/frame
selection. It should not be a cosmetic pass over the old Media card form.

Use manually authored versions of the museum editorial cards plus newsletter
as the first implementation acceptance fixture. Resolve Card structure, link
semantics and shared media handling there. This does not imply replacing any
live-data reference content with static copies in the eventual full page.
Revisit the live-data inventory only as a separate discussion if requested.

For implementation, write failing regressions before fixes, test meaningful
counterexamples, and verify saved/reloaded/published layouts, undo, linked versus
interactive cards, empty/unavailable data, long copy, image ratios, light/dark,
RTL and narrow containers. Screenshot review must read rendered pixels, not
infer visual quality from DOM tests.

No backwards-compatibility layer is required for this pre-release work. Before
removing registrations, enumerate sample layouts, starter content, tests and
theme fixtures that use them and update those deliberately. Do not silently
delete the user's current authored cards. There are no removals in this audit.

## Interactive reference study

The source is [Static card study](mockups/static-card-study.html), an HTML
fragment for the conversation preview. This is a standalone design study, not
a production component or a proposed fixed-field Card schema. Its small form
is an experimental control surface, not the final editor inspector.

It demonstrates four static museum stories using one renderer: a portrait
overlay, landscape overlay and two image-above stories. The same content can
be rearranged in an asymmetric grid, equal grid, wrapping row or stack.
A newsletter appears beside a live-discussion placeholder, matching its
reference placement. Its available width is determined by the containing layout,
not by a Card-specific maximum width. Artwork is illustrative SVG, not the final
reference imagery. Action labels are visual samples, not navigation.

The reference selector now contains all six supplied screenshots. Only static
cards receive detailed treatments; other blocks and site chrome are labeled
placeholders. These are scope choices for the study, not verified statements
about how each reference site's source code implements its content.

| Reference | Detailed static cards | Surrounding placeholders |
| --- | --- | --- |
| Museum | Four editorial stories and newsletter | Hero, discussions, contributors, category navigation |
| HubSpot dark | Champion spotlight, programme promotion, newsletter | Hero, topics/webinars, contributors, categories, chrome |
| Andela | None in this static-card slice | Hero, events, topics, member celebration, chat, chrome |
| Populii | Main Atlas promotion and two compact promotions | Welcome/search, categories, discussions, chrome |
| HubSpot light | Champion spotlight, programme promotion, newsletter | Hero, topic features, contributors, categories, chrome |
| Meta | Three media promotions and download callout | Welcome/search, categories, topic/sidebar widgets, footer |

Andela intentionally introduces no invented static-card variant. Its context
is still represented so the absence of a static Card requirement is explicit.

Presentation changes preserve title, body, action and artwork. “Content only”
hides the artwork without discarding it. Image-beside reflows according to the
card's allocated width. Grid spans live on the containing layout; moving to a
stack does not carry a forced portrait height. The study uses a 640px layout
collapse threshold and a 360px card-side-media threshold as provisional values,
not new approved core breakpoints.

The selected Card's presentation field now explains when Image beside is
currently stacked. The notice responds to allocated-width changes, selection
changes and hidden media, without changing the saved presentation. Tall
image-above cards, including stacked side-media cards, allocate extra height
to media while keeping title/body/action grouped. The two-row grid placement
remains unchanged. The portrait sample uses an explicitly authored 50% / 20%
focal position; this is not automatic face detection.

An unresolved presentation tradeoff is visible in the Meta row: letting media
absorb all spare height keeps content groups compact but can produce unequal
media heights when titles have different lengths. Equal-row media/content
alignment needs further design before adopting this rule as a production
default. Do not introduce this mockup's CSS as the final Card implementation.

### Coordinated natural sizing (2026-09-09)

The wide Stack previously combined 280px overlay frames with unbounded 16:9
media above text. At the 1080px preview setting this yielded approximately
282px overlay cards versus 727px image-above cards. A new regression reproduced
that disproportion rather than merely checking for overflow.

The updated study gives in-flow media a preferred flex basis between 10rem and
20rem, scaling with its own card width between those bounds. This is not a
maximum height: media can still absorb extra space allocated by a tall grid
cell. Overlay frames now use a width-responsive minimum between 17.5rem and
27.5rem. Body content remains uncapped, so long copy increases the overall card
height. There is no Stack-specific fixed total height and no change to the
authored grid spans or selected presentation.

At card widths of at least 640px, the portrait sample uses Fit for image-above
and image-behind treatments. The wide overlay keeps the fitted portrait to the
right and the content on the left; the presentation field explains the fitting
adjustment. This is a deliberate mockup exploration of portrait handling,
not automatic face detection or a finalized change to the image editor's
Fill/Fit contract. Ordinary-width portrait media retains its authored focal
position. Thresholds and size bounds remain provisional design values.

The Stack regression also checks that wide portraits retain the face and very
long copy grows without clipping. It rejects a weaker media-cap-only change
which leaves overlays at their previous narrow height. The earlier tall-cell,
grouped-action, responsive-notice and portrait-crop regressions still pass, as
do the six-reference responsive checks. Wide light/dark and narrow Stack
screenshots were inspected after the change.

Section plain/tinted/image-backed surfaces and Card default/subtle/integrated
surfaces are independent. Default Card retains its paired opaque surface and
foreground; integrated Card inherits Section foregrounds. Image-behind retains
its own scrim and foreground pair, independent of Section treatment.

Local Chromium checks cover 40 width/layout/copy combinations (280, 360, 480,
740 and 1080px; four layouts; short and long copy), preserved titles across
presentations, omitted optional content, restored media, allocated-width side
media reflow, integrated foregrounds and page overflow at a 360px viewport.
Wide light/dark and narrow dark screenshots were inspected. Artwork-definition
and integrated-foreground regressions were observed failing before correction.
These checks exercise only the standalone study, not the Discourse renderer.

Additional checks cover all six references in 246 combinations of viewport
(1152, 736 and 360px), light/dark appearance, reference/equal-grid/row/stack
layout and short/long copy; Andela has no editable card/layout cases. Static
card counts and surrounding placeholders are asserted. Curator regressions
were first observed failing for separated actions, unused tall-cell space,
missing responsive notices and face cropping. The corrected checks also
reject a weaker spacing-only change that leaves unused space below the content.
No production tests, publishing tests or app-theme parity checks are implied.

Still to design and verify before implementation:

- One palette entry and its insertion flow, without four new peer tiles.
- Composable content/part editing instead of adopting this study's fixed fields.
- Selection of Card versus its image versus the containing Section background.
- Whole-card navigation versus independently interactive children.
- Actual Discourse theme parity, RTL visual verification, saving, undo and
  publishing. The study includes an RTL switch but is not proof of RTL parity.
- Cards in nested layouts, explicit constrained heights, and combinations of
  unusually long content with authored fixed sizing.

Production implementation should use the existing FormKit, FloatKit and UI-kit
primitives. This isolated mockup intentionally does not import the app runtime.

### Integrated presentation comparison and row alignment

The [main study](mockups/static-card-study.html) now opens on Meta with
“Compare presentations” enabled. The comparison uses the selected card's actual
content and the same renderer for image-above, image-below, image-beside and
image-behind. The four examples form a two-column comparison when space permits.
Each example has up to 324px of width and a 350px minimum height; longer content
can grow. Reference, Section surface, appearance, content editing, image hiding
and preview width also affect the comparison. The earlier standalone two-card
comparison is superseded and is not the review entry point.

Image-beside offers an adaptive narrow image or a true 50/50 division of the
card interior, plus logical Start/End placement that reverses in RTL. These
choices belong to the selected card, survive placement changes, and also apply
to its comparison example. The initial Meta podcast comparison uses 50/50;
other cards retain their existing defaults. Width and side controls are disabled
when neither the selected placement nor an active comparison uses them.

For cards without body copy, image-beside stays horizontal at allocated widths
from 300 to 360px, using either the selected 50% width or an adaptive 28% image
strip with a compact content gutter. Below
300px it stacks and the comparison label explicitly says so. Cards with body
copy retain the earlier 360px stacking threshold. The narrow crop is a real
trade-off, not a recommendation to make beside the default. Compact overlays
use a content-local scrim to keep their complete titles readable.

“Align content” is enabled by default for matching image-above or matching
image-below cards sharing a visual row in Row, Equal grid and Meta's media
layout. It aligns media/content
boundaries and bottom actions without truncating copy. Each wrapped row is
independent; single cards, Stack, mixed-presentation rows and authored editorial
grids remain independent. This study measures each row's natural content height;
the production mechanism and part-alignment API still need design.

The regression first reproduced a 23px content-boundary mismatch. It now passes
with unequal titles, opt-out, wrapping and Stack release, and rejects a weaker
implementation that leaves actions uneven. The integrated comparison is checked
for all four placements, horizontal side media at 324px and labeled stacking
at narrow widths. Wide light/dark and narrow screenshots were inspected. Existing
40-combination and 246-combination reference checks, tall-cell composition and
wide-Stack sizing checks also pass. These verify the standalone study only, not
the Discourse renderer or production theme/accessibility conformance.

Placement checks additionally verify exact equal media/content widths, Start/End
in both directions, image-below boundaries and actions with unequal titles,
retained content and image-width choices, and long-copy containment at 736, 360
and 320px. The test rejects an image-below option that still draws media above
the body. Above and Below share media sizing and wide-portrait fitting rules;
side images stack above the content at narrow allocations regardless of their
saved Start/End choice. No content is truncated to preserve a fixed card height.
