# Static Card study

Production contract and acceptance gates:
[Static Card implementation plan](../STATIC_CARD_EDITOR_PLAN.md). The study is
the visual target; its sample presets and field names are not the production API.
Existing blocks are pre-release, so no saved-content migration is planned.

Open `static-card-study.html` through the visualization preview, or wrap it using
the visualization renderer for standalone browser use. This is a design mockup,
not production editor code. `card-overlay-comparison.html` is an earlier isolated
comparison; the integrated study is the current entry point.

The leaf-inspector study edits the same card data and renderer as the reference
layout below it. Use Newsletter, Champion, Programme, Speaker and CTA strip to
compare the remaining content treatments. Inspector width choices are 220, 320
and 480 px, capped to the available space. The selected preview follows the
reference card's width when space allows; the full reference remains the source
for stretch, sibling alignment and spanning behavior.

Card stays one leaf node. Content, label/icon, image, action and appearance are
argument controls; groups open contextually for each example. Included proposals:
optional body dividers, title icons/tiles, plain or badge labels, over-image badges
for Behind, link/button actions and responsive beside-text actions for content-
only cards. Preview destinations never navigate. The illustrative image selector
does not implement uploads, crop editing or the production shared image control.

The coverage expansion adds optional identity (name, role, illustrative avatar),
below-title metadata, primary/secondary actions, per-link new-tab intent and
whole-card navigation using the primary destination. The secondary target remains
independent. Empty action labels can still produce a named whole-card link;
missing names or unsupported destinations disable that target, not other actions.
Preview clicks and Enter report the destination without opening a page/tab.
Identity can sit with content or in the media composition. The Speaker example
uses an unboxed portrait/name composition, not a nested profile panel. Badge,
title and duration remain together below. The integrated comparison shows three
formats: compact byline, portrait beside name, and stacked portrait. Format,
placement and circle/rounded portrait shape are independent saved choices.
No-portrait mode retains the name/role. Long identity content grows the media.

Media treatment pairs a full-region backdrop with readable foreground text:
Warm graphic, Theme graphic or Photo with a dark overlay. The warm pairing is
illustrative artwork inspired by the supplied Meta thumbnail and intentionally
stays light in dark mode, like the reference; it is not a hardcoded core theme.
These palette presets are exploratory, not a proposed final production color API.
The silhouette is a placeholder, not a portrait of the named speaker. On-image
identity applies to Above/Below; Beside, Behind and hidden/absent images fall back
to content without changing the saved placement. This is not arbitrary layering.

Everything filled is a separate stress-test reference, not another palette block.
It populates every optional content field, uses Featured emphasis, identity with
an illustrative avatar, a long badge/icon, metadata, body dividers and two long
button labels with independent new-tab links and whole-card navigation. It shows
Above/Beside/Behind together; the selected card also supports Below/content-only
and the existing presentation comparison. Mutually exclusive treatments remain
choices, not simultaneous duplicates. Deliberately excessive copy grows the card;
the mockup does not silently truncate it or shrink the text to fit. It is a
resilience fixture, not the design target for defaults or typical card density.

Reusable Compact/Standard/Featured emphasis, Accent/Contrast paired surfaces and
explicit image fit replace sample-ID font/color and portrait-fit rules. Theme
typography and illustrative artwork remain reference-specific. Fit is preserved
across placement changes, never inferred from the selected artwork.

The side-action arrangement remains a design candidate, not a decision to retire
Banner. Rich-text toolbar/inline editing, embedded body links, production image
handling, editor selection behavior and lifecycle are
not demonstrated here. Do not copy the study's row measurement loop into core.

Verified on 2026-09-09 using local Chromium/Playwright: leaf-field propagation,
conditional visibility, placement retention, action removal/reflow, 48 viewport/
inspector/example combinations, four image placements and even splits in RTL/LTR,
and 246 reference/theme/width/layout/copy combinations. Light/dark screenshots of
the default, narrow and wide inspectors and the mobile stacked view were opened
and inspected. This is not Foundation/Horizon production visual verification.

The expanded coverage check also passes identity/metadata retention, independent
mouse/keyboard action targeting, optional secondary actions, named whole-card
links without visible labels, invalid-primary/valid-secondary behavior, explicit
image fit, reusable presentation controls and 54 width/theme/RTL combinations.
Speaker, two-action and linked-card screenshots were inspected in light/dark.

The unboxed Speaker refinement was checked in 120 format/width/theme/presentation combinations,
including long identity content, accessible text, avatar sizing and placement
fallback. The test rejects the previous boxed identity surface and checks
transparent, in-flow identity layouts rather than a floating profile panel.
The everything-filled check covers 80 width/theme/RTL/presentation combinations,
checking content preservation, overflow and collisions between content regions.
These are standalone Chromium mockup checks, not production editor tests.
