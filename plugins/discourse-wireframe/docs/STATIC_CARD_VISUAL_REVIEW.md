# Static Card visual review

**Latest visual verdict: PASS for the captured Card scenarios.** Complete wide
reader/editor references, narrow reader positions, full stress Cards, image
loading/failure, keyboard focus, RTL/enlarged Card text and the repaired enlarged
image inspector have bounded passing reviews below. This is not a claim that
every editor interaction passes: the Escape teardown investigation is deferred
and non-blocking by user direction, as recorded in
[implementation progress](STATIC_CARD_IMPLEMENTATION.md).

Earlier NEEDS-WORK entries are retained as the defect/repair history; follow-up
sections identify which captures supersede them.

The inspector was resized through its real pointer divider at 240, 300 and 520 px. Each capture below was opened. The earlier CSS-only width captures are superseded: they did not reallocate the canvas.

| Theme/mode | Minimum (240 px) | Default (300 px) | Wide (520 px) |
| --- | --- | --- | --- |
| Foundation light | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-foundation-light-wireframe-card-inspector-240.png): headings stay legible and dividers span the rail; position inputs and picker fit. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-foundation-light-wireframe-card-inspector-300.png): groups have consistent emphasis and boundaries; controls retain their shared alignment. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-foundation-light-wireframe-card-inspector-520.png): the canvas reallocates without panel overlap; controls remain compact while the slider expands. |
| Foundation dark | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-foundation-dark-wireframe-card-inspector-240.png): headings stay legible and dividers span the rail; position inputs and picker fit. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-foundation-dark-wireframe-card-inspector-300.png): groups have consistent emphasis and boundaries; controls retain their shared alignment. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-foundation-dark-wireframe-card-inspector-520.png): the canvas reallocates without panel overlap; controls remain compact while the slider expands. |
| Horizon light | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-horizon-light-wireframe-card-inspector-240.png): headings stay legible and dividers span the rail; position inputs and picker fit. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-horizon-light-wireframe-card-inspector-300.png): groups have consistent emphasis and boundaries; controls retain their shared alignment. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-horizon-light-wireframe-card-inspector-520.png): the canvas reallocates without panel overlap; controls remain compact while the slider expands. |
| Horizon dark | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-horizon-dark-wireframe-card-inspector-240.png): headings stay legible and dividers span the rail; position inputs and picker fit. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-horizon-dark-wireframe-card-inspector-300.png): groups have consistent emphasis and boundaries; controls retain their shared alignment. | [Capture](../../../tmp/wireframe-card-inspector-drag-review/raw/desktop-horizon-dark-wireframe-card-inspector-520.png): the canvas reallocates without panel overlap; controls remain compact while the slider expands. |

Across all twelve shots, unselected Cards omit empty optional text, populated identity/metadata remains visible, and row action edges stay aligned. The selected Card retains its editable body placeholder. The Card’s Media group and the image’s Composition controls now have distinct names.

[Interactive comparison](../../../tmp/wireframe-card-inspector-drag-review/compare.html).

Not established by this capture: opened optional groups at all widths, reader mobile/RTL/text zoom, the full reference compositions, and missing/failed/slow artwork. Interaction evidence is recorded separately in [implementation progress](STATIC_CARD_IMPLEMENTATION.md).

## Narrow reader: first pass

The WebKit run produced 24 screenshots (six references × four theme/palette
combinations). Six Foundation light screenshots and the two Horizon dark HubSpot
screenshots were opened before correcting the defect below. The other first-pass
images are not counted as reviewed.

- [Museum, Foundation light](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-foundation-light-wireframe-card-reader-narrow-museum-cards.png): the visible Behind cards and Above story fit the section; text and actions remain readable. The final story is below the capture.
- [Meta, Foundation light](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-foundation-light-wireframe-card-reader-narrow-meta-cards.png): the unboxed feature identity and stacked identity adapt to one column. Remaining row content is below the capture.
- [HubSpot dark reference, Foundation light](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-foundation-light-wireframe-card-reader-narrow-hubspot-dark.png): **FAIL**, Champion badge overlaps the title. Newsletter icon and copy are contained.
- [HubSpot light reference, Foundation light](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-foundation-light-wireframe-card-reader-narrow-hubspot-light.png): **FAIL**, same badge/title collision.
- [Populii, Foundation light](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-foundation-light-wireframe-card-reader-narrow-populii-cards.png): Beside falls back to Above at this allocation; the primary action and accent promo remain legible.
- [Meta Below, Foundation light](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-foundation-light-wireframe-card-reader-narrow-meta-below.png): content precedes the identity artwork without clipping in the visible cards.
- [HubSpot dark reference, Horizon dark](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-horizon-dark-wireframe-card-reader-narrow-hubspot-dark.png): **FAIL**, same badge/title collision, not a Foundation-only defect.
- [HubSpot light reference, Horizon dark](../../../tmp/wireframe-card-reader-mobile-review/raw/mobile-horizon-dark-wireframe-card-reader-narrow-hubspot-light.png): **FAIL**, same collision on the subtle Section surface.

The containment test did not compare sibling regions. Its strengthened overlap
assertion failed before a shared-row CSS fix and passed afterward. A longer,
double-text-size QUnit case also rejected a top-alignment-only repair. Updated
screenshots are required before accepting the fix visually.

## Narrow reader: refreshed review

All 24 refreshed PNGs were opened (5 examples, seed 7510). The table records
only visible content, not an acceptance claim for cards below the viewport.
The floating editor entry pill obscures small lower-right areas in these
signed-in captures; it is not Card content.

| Reference | Foundation light | Foundation dark | Horizon light | Horizon dark | Observation |
| --- | --- | --- | --- | --- | --- |
| Museum | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-light-wireframe-card-reader-narrow-museum-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-dark-wireframe-card-reader-narrow-museum-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-light-wireframe-card-reader-narrow-museum-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-dark-wireframe-card-reader-narrow-museum-cards.png) | Curator and exhibition copy/actions stay separate and legible over artwork; the Above story fits. Final story remains below the viewport. |
| Meta Above | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-light-wireframe-card-reader-narrow-meta-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-dark-wireframe-card-reader-narrow-meta-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-light-wireframe-card-reader-narrow-meta-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-dark-wireframe-card-reader-narrow-meta-cards.png) | Feature and stacked identities remain unboxed; visible text fits. Final story remains below the viewport. |
| HubSpot dark reference | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-light-wireframe-card-reader-narrow-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-dark-wireframe-card-reader-narrow-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-light-wireframe-card-reader-narrow-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-dark-wireframe-card-reader-narrow-hubspot-dark.png) | Champion badge and title are separated; newsletter icon, copy and divider fit. Lower editorial cards remain outside this capture. |
| HubSpot light reference | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-light-wireframe-card-reader-narrow-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-dark-wireframe-card-reader-narrow-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-light-wireframe-card-reader-narrow-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-dark-wireframe-card-reader-narrow-hubspot-light.png) | Champion badge and title are separated; newsletter remains readable on the subtle Section surface. Lower editorial cards remain outside this capture. |
| Populii | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-light-wireframe-card-reader-narrow-populii-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-dark-wireframe-card-reader-narrow-populii-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-light-wireframe-card-reader-narrow-populii-cards.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-dark-wireframe-card-reader-narrow-populii-cards.png) | Beside adapts to Above; the long primary button label fits. Accent promo remains legible; the contrast promo is only partly visible. |
| Meta Below | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-light-wireframe-card-reader-narrow-meta-below.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-foundation-dark-wireframe-card-reader-narrow-meta-below.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-light-wireframe-card-reader-narrow-meta-below.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-refined/raw/mobile-horizon-dark-wireframe-card-reader-narrow-meta-below.png) | Copy/actions precede the identity artwork, with readable feature and stacked identities. Third card remains partly below the viewport. |

[Refreshed comparison](../../../tmp/wireframe-card-reader-mobile-refined/compare.html).

Foundation dark's Above capture initially showed a barely visible Hawk initial,
while the same identity in Below and Horizon dark was clear. A focused repeat
checked the rendered initial and its computed foreground against the adjacent
name, then produced a [clear initial](../../../tmp/wireframe-card-initials-diagnostic/raw/mobile-foundation-dark-wireframe-card-reader-narrow-meta-cards.png)
without a production CSS change (2 examples, seed 7510). The inconsistency is
recorded, not claimed fixed; the check does not establish why the first capture
differed. The first attempt filtered a dynamic marker by its expanded label and
ran no Card example; only the shared-prefix rerun counts as coverage.

**Verdict: NEEDS-WORK** for full acceptance. The visible narrow badge/title
collision is absent across all four theme/palette combinations. Full lower
reference content, RTL/text zoom and failed/slow artwork still need their own
rendered coverage.

## Narrow reader: lower reference review

All 32 lower-position PNGs were opened after the capture run passed (5 examples,
seed 7510). This completes the bounded review of the positions below, not the
entire desktop/RTL/zoom or asynchronous-image acceptance matrix.

| Reference | Foundation light | Foundation dark | Horizon light | Horizon dark | Observation |
| --- | --- | --- | --- | --- | --- |
| Museum stories | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-museum-neutrino.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-museum-neutrino.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-museum-neutrino.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-museum-neutrino.png) | Both Above stories have bounded artwork, complete copy/actions and a consistent gap. |
| Meta Above final story | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-meta-falling-apart.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-meta-falling-apart.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-meta-falling-apart.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-meta-falling-apart.png) | The compact photo identity stays readable over busy artwork; the long title fits. The following guide CTA stacks and its button fits. |
| HubSpot dark programme | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-hubspot-dark-programme.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-hubspot-dark-programme.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-hubspot-dark-programme.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-hubspot-dark-programme.png) | Icon tile, wrapped heading, copy and action fit with clear spacing. |
| HubSpot dark roundtable | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-hubspot-dark-roundtable.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-hubspot-dark-roundtable.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-hubspot-dark-roundtable.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-hubspot-dark-roundtable.png) | Roundtable and agents copy/actions remain complete. Only the bottom of the UNBOUND highlight is visible. |
| HubSpot light programme | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-hubspot-light-programme.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-hubspot-light-programme.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-hubspot-light-programme.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-hubspot-light-programme.png) | Icon tile, wrapped heading, copy and action fit with clear spacing. |
| HubSpot light roundtable | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-hubspot-light-roundtable.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-hubspot-light-roundtable.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-hubspot-light-roundtable.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-hubspot-light-roundtable.png) | Roundtable and agents copy/actions remain complete. Only the bottom of the UNBOUND highlight is visible. |
| Populii promos | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-populii-gig.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-populii-gig.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-populii-gig.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-populii-gig.png) | Both content-only promos fit; accent/contrast surfaces retain readable foregrounds in either mode. |
| Meta Below final story | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-light-wireframe-card-reader-lower-meta-falling-apart-below.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-foundation-dark-wireframe-card-reader-lower-meta-falling-apart-below.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-light-wireframe-card-reader-lower-meta-falling-apart-below.png) | [Capture](../../../tmp/wireframe-card-reader-mobile-lower/raw/mobile-horizon-dark-wireframe-card-reader-lower-meta-falling-apart-below.png) | The action precedes the artwork; the unboxed photo identity stays readable. Only the top of the following stress case is visible. |

[Lower-reference comparison](../../../tmp/wireframe-card-reader-mobile-lower/compare.html).

No additional clipping or overlapping Card regions were visible in these shots.
The complete UNBOUND highlights and stress-case bottoms still need dedicated
positions. The signed-in editor entry pill obscures a small bottom-right area;
partially visible neighboring cards are not counted as fully reviewed.

## Whole-card keyboard focus

**Verdict: PASS** for the whole-card-only focus repair. The keyboard flow passed
in all four desktop theme/mode combinations (5 examples, seed 7510), and every
PNG below was opened. Each shows a complete inset ring around the collection
Card, without clipping or changing its content layout.

- [foundation light](../../../tmp/wireframe-card-keyboard-review/raw/desktop-foundation-light-wireframe-card-keyboard-whole.png): the ring remains visible along all four edges and follows the theme's corner shape.
- [foundation dark](../../../tmp/wireframe-card-keyboard-review/raw/desktop-foundation-dark-wireframe-card-keyboard-whole.png): the ring remains visible along all four edges and follows the theme's corner shape.
- [horizon light](../../../tmp/wireframe-card-keyboard-review/raw/desktop-horizon-light-wireframe-card-keyboard-whole.png): the ring remains visible along all four edges and follows the theme's corner shape.
- [horizon dark](../../../tmp/wireframe-card-keyboard-review/raw/desktop-horizon-dark-wireframe-card-keyboard-whole.png): the ring remains visible along all four edges and follows the theme's corner shape.

[Keyboard comparison](../../../tmp/wireframe-card-keyboard-review/compare.html).

The original failed system screenshot showed no cue around the focused Card.
The new ring uses the existing overlay, so it adds no tab stop. The test also
checks primary, secondary and body-link focus/navigation and their independent
pointer targets; those interactions cannot be established by this screenshot.
This does not close the remaining overall Card acceptance gates.

## Delayed and failed feature artwork

**Verdict: PASS** for readability and stable row layout in the captured desktop
states. All eight PNGs were opened after the four-theme/mode capture passed
(5 examples, seed 7510). Sam's independent portrait and identity remain visible
while the feature request is held and after a 404; the Card retains its themed
media surface, readable copy, and aligned actions. The failure state shows the
browser's small broken-image indicator at the media's upper-start edge; this is
not a custom error/retry UI.

| Theme / mode | Pending request | Failed request | Observation |
| --- | --- | --- | --- |
| foundation light | [Pending](../../../tmp/wireframe-card-artwork-review/raw/desktop-foundation-light-wireframe-card-artwork-pending.png) | [Failed](../../../tmp/wireframe-card-artwork-review/raw/desktop-foundation-light-wireframe-card-artwork-failed.png) | Identity remains unboxed and readable; media seams and actions match the adjacent cards in both states. |
| foundation dark | [Pending](../../../tmp/wireframe-card-artwork-review/raw/desktop-foundation-dark-wireframe-card-artwork-pending.png) | [Failed](../../../tmp/wireframe-card-artwork-review/raw/desktop-foundation-dark-wireframe-card-artwork-failed.png) | Identity remains unboxed and readable; media seams and actions match the adjacent cards in both states. |
| horizon light | [Pending](../../../tmp/wireframe-card-artwork-review/raw/desktop-horizon-light-wireframe-card-artwork-pending.png) | [Failed](../../../tmp/wireframe-card-artwork-review/raw/desktop-horizon-light-wireframe-card-artwork-failed.png) | Identity remains unboxed and readable; media seams and actions match the adjacent cards in both states. |
| horizon dark | [Pending](../../../tmp/wireframe-card-artwork-review/raw/desktop-horizon-dark-wireframe-card-artwork-pending.png) | [Failed](../../../tmp/wireframe-card-artwork-review/raw/desktop-horizon-dark-wireframe-card-artwork-failed.png) | Identity remains unboxed and readable; media seams and actions match the adjacent cards in both states. |

[Artwork-state comparison](../../../tmp/wireframe-card-artwork-review/compare.html).

The system flow separately verifies actual pending/failed/loaded image properties,
request recovery and unchanged peer heights. These captures cover the feature
image in a theme-treated identity row, not every failed-image presentation or
portrait failure, and do not establish the remaining overall visual acceptance.

## Complete desktop highlights and stress Cards

**Verdict: PASS** for the complete target Cards at these allocations. The capture
run passed (5 examples, seed 7510), and all 24 PNGs were opened. Viewport height
is derived from the target Card so the lower actions/identity are included, with
an assertion that the target fits in view before capture. Neighboring Cards are
incidental and may remain partly outside the shot.

| Target | Foundation light | Foundation dark | Horizon light | Horizon dark | Observation |
| --- | --- | --- | --- | --- | --- |
| HubSpot dark-reference highlight | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-light-wf-card-full-hubspot-dark-highlight.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-dark-wf-card-full-hubspot-dark-highlight.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-light-wf-card-full-hubspot-dark-highlight.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-dark-wf-card-full-hubspot-dark-highlight.png) | The complete UNBOUND title/action remains readable over the image. |
| HubSpot light-reference highlight | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-light-wf-card-full-hubspot-light-highlight.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-dark-wf-card-full-hubspot-light-highlight.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-light-wf-card-full-hubspot-light-highlight.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-dark-wf-card-full-hubspot-light-highlight.png) | The complete highlight retains its own readable overlay on a subtle Section. |
| Fully populated Above | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-light-wf-card-full-stress-above.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-dark-wf-card-full-stress-above.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-light-wf-card-full-stress-above.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-dark-wf-card-full-stress-above.png) | Identity, long label/title/meta/body and both actions are complete on an integrated surface. |
| Fully populated Below | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-light-wf-card-full-stress-below.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-dark-wf-card-full-stress-below.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-light-wf-card-full-stress-below.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-dark-wf-card-full-stress-below.png) | Both actions precede the complete media identity; no field is clipped. |
| Fully populated Beside at 320px | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-light-wf-card-full-stress-beside.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-dark-wf-card-full-stress-beside.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-light-wf-card-full-stress-beside.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-dark-wf-card-full-stress-beside.png) | The narrow fallback is Above, with all content retained; this is not proof of the wide split. |
| Fully populated Behind | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-light-wf-card-full-stress-behind.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-foundation-dark-wf-card-full-stress-behind.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-light-wf-card-full-stress-behind.png) | [Capture](../../../tmp/wireframe-card-complete-review/raw/desktop-horizon-dark-wf-card-full-stress-behind.png) | The overlay keeps all content readable and both actions visible; the Card grows with its copy. |

The intentionally narrow 320px stress allocation leaves spare Section width;
that whitespace is fixture allocation, not a proposed page composition. Integrated
Cards remain visually dense over the busy Section artwork, but their foregrounds
are readable in both modes and the complete fields do not overlap. Behind has its
own stronger surface. These are extreme examples, not insertion defaults.

[Complete Card comparison](../../../tmp/wireframe-card-complete-review/compare.html).

The first capture invocation selected no Card examples because its markers were
multiline and the runner discovers labels on the call's first line. Shortening
the marker calls made them discoverable. Only the subsequent 24-image run counts.
This closes the missing desktop highlight/stress-bottom positions, not the
remaining RTL/text-zoom or active-editor visual gates.

## Doubled text and RTL direction

**Verdict: NEEDS-WORK** for the complete editor surface; the Card regions pass
the bounded readability/geometry check. The capture run passes 5/5 (seed 7510),
and all eight PNGs were opened. The three media stories wrap into separate rows;
their content, media identities and actions remain contained and readable. Editing
the first identity to a long Arabic name retains the full name and portrait.

| Theme / mode | Reader | Editor | Observation |
| --- | --- | --- | --- |
| Foundation light | [Reader](../../../tmp/wireframe-card-rtl-review/raw/desktop-foundation-light-wf-card-rtl-reader.png) | [Editor](../../../tmp/wireframe-card-rtl-review/raw/desktop-foundation-light-wf-card-rtl-editor.png) | Cards retain legible theme/photo identities. The inspector's source labels split into word fragments, and Fit/Zoom labels crowd their controls. |
| Foundation dark | [Reader](../../../tmp/wireframe-card-rtl-review/raw/desktop-foundation-dark-wf-card-rtl-reader.png) | [Editor](../../../tmp/wireframe-card-rtl-review/raw/desktop-foundation-dark-wf-card-rtl-editor.png) | Card copy/actions remain readable. The same inspector crowding remains visible in dark mode. |
| Horizon light | [Reader](../../../tmp/wireframe-card-rtl-review/raw/desktop-horizon-light-wf-card-rtl-reader.png) | [Editor](../../../tmp/wireframe-card-rtl-review/raw/desktop-horizon-light-wf-card-rtl-editor.png) | Card surfaces and rounded actions adapt to Horizon; enlarged inspector source labels and composition controls need reflow. |
| Horizon dark | [Reader](../../../tmp/wireframe-card-rtl-review/raw/desktop-horizon-dark-wf-card-rtl-reader.png) | [Editor](../../../tmp/wireframe-card-rtl-review/raw/desktop-horizon-dark-wf-card-rtl-editor.png) | Theme/photo identities remain readable; the inspector has the same narrow effective-width defect. |

[RTL/text-size comparison](../../../tmp/wireframe-card-rtl-review/compare.html).

This fixture doubles the root font size and explicitly sets root direction to
RTL, while keeping English interface strings and the normal test stylesheet.
It is not a fully localized Arabic application or browser-zoom test. The visible
English metadata reordering therefore is not evidence of correct mixed-language
formatting. The enlarged inspector defect remains an acceptance item.

The initial geometry assertion incorrectly included hidden empty fields from
unselected editor Cards. Diagnostics showed zero-sized boxes at the document
origin, not clipped populated fields. The assertion now excludes only fields
marked empty and styled display:none; visible editing placeholders and populated
fields remain checked. The corrected focused flow passes 1/1 (seed 8186).

## Enlarged inspector follow-up

**Verdict: NEEDS-WORK** for one remaining minimum-width action label. The
24-capture run completed with 5/5 passing examples (seed 7510); all images were
opened across Foundation/Horizon, light/dark, LTR/RTL and 240/300/520px rails.
The existing source and composition regression passes these combinations.

- At 240px, source summaries now put their labels beneath the thumbnail and
  chevron. Default image and Add dark variant wrap at word boundaries; Fit uses
  its existing select fallback, and Zoom stacks above its input.
- At 300px, source labels remain complete, Fit retains its segmented control,
  and Position keeps the drag area below the number inputs.
- At 520px, source summaries and composition property rows remain horizontal,
  with the Position drag area beside the inputs. RTL mirrors the controls.
- In both themes and modes, the 240px Reposition on canvas button still splits
  Reposition into fragments. The geometry regression is being extended to include
  action words, rather than treating the passing source/row checks as acceptance
  of that label.

[Enlarged inspector comparison](../../../tmp/wireframe-card-enlarged-inspector-review/compare.html).
Each capture includes the complete image control. Incidental canvas content may
be outside the visible allocation; these are not whole-Card acceptance shots.

## Enlarged inspector: action-label repair

**Verdict: PASS** for the enlarged image inspector. The run under
`tmp/wireframe-card-enlarged-inspector-final` finished with 5/5 examples
(seed 7510), and all 24 Foundation/Horizon light/dark, LTR/RTL,
240/300/520px captures have been opened.
The Reposition action now wraps at whole-word boundaries, stays inside its
button and retains the same shared input/picker styling. Source summaries and
Fit/Zoom controls remain readable at each width. Horizon's rounded actions also
contain the complete label. At 240px, Fit uses the select fallback and Position
stacks; at 520px, the picker sits beside the inputs and follows their height.
The capture scope remains the image inspector, not partially visible canvas
neighbors or a fully localized RTL application.

[Repaired enlarged inspector comparison](../../../tmp/wireframe-card-enlarged-inspector-final/compare.html).

## Complete wide reader and editor references

**Verdict: PASS** for the six complete reference groups in reader and active
editor modes. The capture run passed 5/5 examples (seed 7510), and all 48 PNGs
were opened. Each reference uses a measured viewport height and an assertion
that every target Card fits in view. No Card is selected in the editor captures;
selected fields and inspector states have separate checks above.

The screenshots use the installed core themes and their palettes, not replicas
of the references' branding. In particular, the HubSpot reference names identify
compositions, not a forced light/dark palette. Artwork is illustrative; a cropped
portrait in the even-split promo reflects its authored image composition.

| Reference / mode | Foundation light | Foundation dark | Horizon light | Horizon dark | Observation |
| --- | --- | --- | --- | --- | --- |
| Museum / reader | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-reader-museum-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-reader-museum-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-reader-museum-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-reader-museum-cards.png) | Tall curator and wide exhibition retain their editorial proportions; the two Above stories share media boundaries and bottom actions. |
| Museum / editor | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-editor-museum-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-editor-museum-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-editor-museum-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-editor-museum-cards.png) | Tall curator and wide exhibition retain their editorial proportions; the two Above stories share media boundaries and bottom actions. Editor allocation changes text wrapping without hiding content or breaking these boundaries. |
| Meta Above / reader | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-reader-meta-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-reader-meta-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-reader-meta-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-reader-meta-cards.png) | The three media seams and actions align; feature, stacked and compact identities stay unboxed, with readable theme/photo treatments. The guide CTA fits alongside its copy. |
| Meta Above / editor | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-editor-meta-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-editor-meta-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-editor-meta-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-editor-meta-cards.png) | The three media seams and actions align; feature, stacked and compact identities stay unboxed, with readable theme/photo treatments. The guide CTA fits alongside its copy. Editor allocation changes text wrapping without hiding content or breaking these boundaries. |
| HubSpot dark reference / reader | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-reader-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-reader-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-reader-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-reader-hubspot-dark.png) | The complete champion, newsletter, programme, UNBOUND highlight and mixed-media lower pair fit. Badge and title remain separated; lower actions share an edge. |
| HubSpot dark reference / editor | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-editor-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-editor-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-editor-hubspot-dark.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-editor-hubspot-dark.png) | The complete champion, newsletter, programme, UNBOUND highlight and mixed-media lower pair fit. Badge and title remain separated; lower actions share an edge. Editor allocation changes text wrapping without hiding content or breaking these boundaries. |
| HubSpot light reference / reader | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-reader-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-reader-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-reader-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-reader-hubspot-light.png) | The same complete composition fits on the subtle Section surface, with visible newsletter dividers and separated champion badge/copy. |
| HubSpot light reference / editor | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-editor-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-editor-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-editor-hubspot-light.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-editor-hubspot-light.png) | The same complete composition fits on the subtle Section surface, with visible newsletter dividers and separated champion badge/copy. Editor allocation changes text wrapping without hiding content or breaking these boundaries. |
| Populii / reader | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-reader-populii-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-reader-populii-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-reader-populii-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-reader-populii-cards.png) | The promo retains its even image/content split and logical end image; the primary button is complete. Both content-only promos retain paired, readable foregrounds. |
| Populii / editor | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-editor-populii-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-editor-populii-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-editor-populii-cards.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-editor-populii-cards.png) | The promo retains its even image/content split and logical end image; the primary button is complete. Both content-only promos retain paired, readable foregrounds. Editor allocation changes text wrapping without hiding content or breaking these boundaries. |
| Meta Below / reader | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-reader-meta-below.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-reader-meta-below.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-reader-meta-below.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-reader-meta-below.png) | The complete copy/actions precede the identity artwork; all three lower media seams align and identities remain readable. |
| Meta Below / editor | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-light-wf-card-wide-editor-meta-below.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-foundation-dark-wf-card-wide-editor-meta-below.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-light-wf-card-wide-editor-meta-below.png) | [Capture](../../../tmp/wireframe-card-wide-final/raw/desktop-horizon-dark-wf-card-wide-editor-meta-below.png) | The complete copy/actions precede the identity artwork; all three lower media seams align and identities remain readable. Editor allocation changes text wrapping without hiding content or breaking these boundaries. |

[Complete wide comparison](../../../tmp/wireframe-card-wide-final/compare.html).

Horizon uses rounder corners/actions and different content allocation from
Foundation; both retain complete text and actions. Contrast surfaces deliberately
reverse their foreground/background pairing in dark mode. Neighboring references,
site chrome and live-data placeholders are incidental and are not accepted as
page recreations. These wide captures supplement, rather than replace, the
narrow, enlarged-text, keyboard and asynchronous-artwork checks above.
