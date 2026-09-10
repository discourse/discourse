# Leaf Card: mockup goal impact

Current contract and delivery strategy:
[Static Card implementation plan](STATIC_CARD_EDITOR_PLAN.md). This assessment
predates the later identity/action mockups and pre-release clean-break decision;
retain it as design history, not migration or renderer-retention instructions.

Date: 2026-09-09. Source-level assessment of the accepted static-card study and
the supplied reference screenshots. No preview or production code changed; no
new browser verification performed for this assessment. The subsequent
[leaf-inspector mockup update](mockups/README.md) now demonstrates the newsletter,
badge/icon and action treatments identified below; its verification is recorded
separately. The scenario table remains the pre-update gap assessment.

Product direction: Card remains a leaf in the editor tree. Its content and
presentation are arguments, not authored children or synthesized editable parts.
This supersedes the container recommendation in the previous implementation
draft. A leaf does not preclude inline editing of its own rich-text fields.

## Finding

The approved study already uses fixed-field cards. `staticCard` and `renderCard`
in [the study](mockups/static-card-study.html) use title, copy, eyebrow, one action,
image and presentation settings. There is no child-block composition supporting
its visual results. Consequently, retaining a leaf does not require abandoning
the study's four image placements, content-only mode, beside split/side choices,
or coordinated row boundaries.

This is structural evidence, not proof that the full references are reproduced.
The study simplifies several details and includes sample-specific CSS. Those
details need explicit decisions instead of being attributed to container support.

## Scenario coverage

| Scenario | Leaf fit | Remaining fidelity decisions |
| --- | --- | --- |
| Museum curator and exhibition feature | Image behind, title, body and action fit directly. Tall/wide spans remain Layout responsibilities. | General preferred sizing, overlay contrast and crop behavior must replace asset-specific curator rules. |
| Museum collection/member stories | Image above, eyebrow, title, body and action fit directly; below/beside are alternate presentations of the same content. | Shared media/content seams and action alignment remain required. No independent extra arrow destination should be inferred from the reference. |
| Museum and HubSpot newsletter | Content-only, title icon, body and action fit without child blocks. | The study hardcodes dividers around newsletter copy. A reusable divided-content treatment can preserve this detail without draggable Divider children. This is a proposed option, not an existing control. |
| HubSpot champion | Image behind, eyebrow, title, body and action fit directly. | The reference's outlined champion badge is simplified to an eyebrow in the study. Badge styling/placement needs a bounded design if that fidelity is required. |
| HubSpot programme promotion | Content-only, icon, title, body and action fit directly. | The reference's icon tile is not represented by the study's programme renderer. Define an intentional icon treatment rather than sample-ID styling. |
| Populii Atlas promotion | Image beside/end, title, body and action fit directly. | The study simplifies the photographic background into a side-image treatment and uses sample-specific large title/padding. Button-style action and a bounded featured scale need validation; a region-level hero can remain Section composition. |
| Populii small promos | Content-only, eyebrow, title and body fit directly. | Replace sample-ID red/dark colors with deliberate theme-aware paired surfaces. Preserve any authored destination, even without a visible action label. |
| Meta Watch & Listen | Image above, eyebrow/badge, title and action fit directly, including long titles and row alignment. | Reference speaker artwork and badge treatment are simplified in the study. Supplied artwork can carry baked-in visual identity, but editable avatar/name/role is a separate requirement, not equivalent to an image. |
| Meta guide CTA strip | Title, body and one action fit as data. | The study renders the action below the copy; the reference puts a button beside it. A responsive inline-action treatment or existing banner composition is needed for that geometry. Image-beside does not solve action placement. |
| Andela | No new static-card requirement is demonstrated by this study scenario. | All its regions are placeholders. Event/member/channel blocks remain out of scope; do not claim leaf Card reproduces them. |

HubSpot topic features and the category/topic/member regions in the other
references are also placeholders, not evidence of static Card coverage.

## Smallest useful leaf contract

Core content: title, supporting rich text, optional eyebrow, optional icon and
one optional action label/destination. Retain a deliberate whole-card navigation
contract without introducing competing destinations by accident. A visible action
may use a text-link or button treatment. Empty optional fields reserve no gaps.

Feature media: shared image value, alt/decorative intent and composition; content
only/above/below/beside/behind; conditional split and logical-side choices.

Appearance: a small set of paired surfaces and bounded defaults. Newsletter
separators, badge/icon treatment and compact versus featured sizing are candidates
to validate, not permission to add a generic style editor. Inline-action layout
needs its own comparison before deciding whether it belongs in Card or Banner.

Keep Content, Image and Appearance in the existing schema-driven FormKit
inspector. Reveal optional groups and placement-specific controls when relevant;
do not turn all candidate fidelity features into always-visible fields. One Card
entry and one outline node; no children, action-region role or detach workflow.

The editing contract intentionally excludes arbitrary block insertion/reordering,
embedded live widgets and unrestricted collections of actions. None powers the
current static study. Requests for those should use an appropriate existing
composition rather than silently expanding every Card.

## Layout and Section implications

Section still owns region background, padding and content width. Layout still
owns item allocation, spans, gaps, wrapping and compatible-row alignment. Card
owns its known media/content/action regions. Leaf ownership simplifies identifying
those regions; it does not remove the need to prove alignment through reader and
editor wrappers, unequal widths and responsive transitions.

Retain all sizing acceptance goals: bounded media growth in Stack, deliberate
spare-height allocation in tall Grid cells, natural long-text growth, allocated-
width reflow, true 50/50 beside, RTL, and release of row alignment on wrapping or
incompatible geometry. Above/Below action placement is renderer-owned, not a role
the author has to manage. Preserve crop/source/content when presentation changes.

## Catalogue and saved-content limitation

The simple leaf contract does not yet replace every existing static-card feature.
Current `media-card.gts` has avatar/name/role and badge icon/label arguments;
`wf:cta-card` includes a two-button `wf:cta-actions` composite. The study's single
action and feature image do not cover those contracts. Existing `card.gts` also
has a meta field below its title; do not silently relabel/move that content into
an above-title eyebrow during consolidation.

Do not remove those renderers or convert their saved content until an explicit
mapping or retention decision is approved. The leaf direction reduces the need
for new container serialization, but does not authorize losing independent
destinations, identity fields, rich text, upload metadata or composite overrides.

## Effect on the implementation draft

Remove the proposed child schema, action-role commands, seeded child subtrees,
outline-role UI and Card-specific reparenting behavior. Evolve the existing leaf
renderer/schema instead. Retain shared image integration, inspector consistency,
real-wrapper alignment proof, safe saved-content handling and actual-theme visual
verification. Do not treat the previous draft's review approval as approval of a
new leaf schema; that schema still needs review after the fidelity choices settle.

Recommended next validation: keep the accepted compositions and compare the
missing newsletter, badge/icon and action treatments inside one leaf inspector
mockup at narrow/default widths. The goal is to validate authoring simplicity as
well as appearance before adding production arguments.

## Review boundaries

Design-conformance guidance influenced the recommendation to retain the existing
FormKit/schema shell, reuse shared image controls, conditionally expose fields,
use translated Sentence-case labels and theme-aware surfaces, and avoid copying
sample-specific CSS. This assessment does not claim fresh aesthetic verification,
code-convention review, or correctness/performance/security review. Those remain
separate implementation gates.
