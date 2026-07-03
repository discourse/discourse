/**
 * Editor thumbnail for an outlet: a small cluster of blocks.
 *
 * An outlet is a named region of a page (not a block), and the on-canvas outlet
 * handle already reads as a cluster of cubes (the `cubes` icon), so this
 * thumbnail draws a matching cluster to keep the outlet's identity consistent
 * between the canvas badge and the inspector header.
 *
 * It's a flat mini-mockup in the same language as the core block thumbnails:
 * three rounded squares, no depth. The squares sit in a cluster (one above two)
 * rather than an aligned row or grid, so the mark stays distinct from the
 * `layout` grid and the `stats` row, and a single `--tertiary` accent (the top
 * square) follows the set's one-sparing-accent convention. Everything is theme
 * tokens, so it recolors for any theme.
 *
 * Forwards `...attributes` onto the root `<svg>` so a caller's sizing class (e.g.
 * the inspector header's) lands on the SVG.
 */
const OutletThumbnail = <template>
  <svg
    class="wireframe-outlet-thumbnail"
    viewBox="0 0 120 80"
    fill="none"
    aria-hidden="true"
    ...attributes
  >
    {{! Two base squares side by side, with the accent square centered above them }}
    <rect
      x="25"
      y="44"
      width="30"
      height="28"
      rx="4"
      fill="var(--primary-low)"
    />
    <rect
      x="65"
      y="44"
      width="30"
      height="28"
      rx="4"
      fill="var(--primary-low)"
    />
    <rect x="45" y="12" width="30" height="28" rx="4" fill="var(--tertiary)" />
  </svg>
</template>;

export default OutletThumbnail;
