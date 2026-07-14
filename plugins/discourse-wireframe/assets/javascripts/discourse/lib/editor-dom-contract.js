// @ts-check

/**
 * The DOM "contract" the editor relies on when it reads markup produced by
 * the live-rendered blocks. These are the seams where the editor and the
 * render path meet: the editor queries by these selectors / attributes, but a
 * DIFFERENT layer (core's block components) emits the matching DOM. A rename
 * on the producing side breaks the editor silently — no error, the
 * `querySelector` just returns `null` — which is exactly how a one-line class
 * rename once took out every grid drop zone.
 *
 * Centralising them here means:
 *  - a producer-side rename is a single edit in this file, and
 *  - the `editor-dom-contract` test renders the REAL producers and asserts
 *    each of these still resolves, so the rename fails a fast test instead of
 *    shipping a silent regression.
 *
 * Only CROSS-CODEBASE seams (core render → editor) belong here. Purely
 * editor-internal markup (chrome wrappers, the grid overlay's own cells) is
 * exercised behaviourally by the drag-gesture and system tests instead.
 */

/**
 * The layout block's CSS Grid container — the `<div>` core's `layout` block
 * renders for grid mode (class `d-block-layout d-block-layout--grid`). The
 * editor locates it to mount the grid overlay + drop target and to measure
 * cells for resize. If it stops resolving, the overlay never mounts and grid
 * drag-and-drop silently disappears.
 *
 * @type {string}
 */
export const GRID_LAYOUT_SELECTOR = ".d-block-layout--grid";

/**
 * Attribute core's editable blocks (button-link, heading, callout, image,
 * media-card, cta-banner, …) stamp on each inline-editable / image arg
 * element. The editor reads it to wire the URL popover and the image-arg
 * overlays. A rename breaks those affordances silently.
 *
 * @type {string}
 */
export const BLOCK_ARG_ATTR = "data-block-arg";

/**
 * Selector form of {@link BLOCK_ARG_ATTR}.
 *
 * @type {string}
 */
export const BLOCK_ARG_SELECTOR = `[${BLOCK_ARG_ATTR}]`;
