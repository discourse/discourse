// @ts-check

/**
 * The CSS selector for the layout block's CSS Grid container element —
 * the `<div>` the core `layout` block renders for grid mode (its class
 * is `d-block-layout d-block-layout--grid`).
 *
 * The editor locates this element to (a) mount the grid overlay's cells
 * and drop target into the same CSS Grid context the slots live in, and
 * (b) measure cell sizes for resize. It lives in one place so the render
 * side and the editor can't silently drift: if the render-side class is
 * renamed, this single constant is the one edit — and the grid-DOM
 * contract test catches the mismatch.
 *
 * @type {string}
 */
export const GRID_LAYOUT_SELECTOR = ".d-block-layout--grid";
