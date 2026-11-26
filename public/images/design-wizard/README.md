# Design wizard theme previews

The wizard uses these dedicated illustrations instead of uploaded theme screenshots.
Each theme has a light and dark WebP at 1600 × 1000 (8:5). The image dimensions in
`design-wizard/theme-section.gjs` and the frame in `design-wizard.scss` must keep
this aspect ratio. Preserve the full header and both horizontal edges; Concord
also needs its right-hand member list.

These assets were generated with the built-in image generation tool from full-width
Foundation, Horizon, and Concord screenshots. Text is abstracted into subdued
strokes while navigation icons, surfaces, theme colors, and content structure
remain recognizable. The dark versions are illustrative default palettes, not
previews of the user's selected color scheme.

## Prompt recipe

For light versions, use a full-width screenshot as the reference. Request a
faithful flat UI silhouette, preserving the header, top-right controls, sidebar,
and theme-specific cards, table, or conversation columns. Replace text with thin,
low-contrast gray strokes, with slightly darker titles. Keep the original icons
and accent colors. Avoid decorative gradients, shadows, oversized rounding, and
invented controls. Shorten vertical empty space to fit an 8:5 frame without
cropping either horizontal edge.

For dark versions, use the approved light illustration as the reference. Change
only colors: charcoal main surface (#222222), darker sidebar/header (#191919),
fine borders (#383838), and subdued text strokes (#53565b and #666a70). Horizon
uses a muted dark-purple outer shell (#211f30), charcoal main panel (#242424), and
lavender accents. Preserve composition, icons, avatars, controls, and columns.

Export to WebP at quality 85. Check all six assets together at the actual wizard
card size before replacing them.
