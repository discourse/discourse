import { modifier } from "ember-modifier";

// Fallback aspect (width / height) for tiles whose media hasn't reported its
// intrinsic size yet, and for avatar-only tiles. Matches a landscape camera.
export const DEFAULT_TILE_ASPECT = 16 / 9;

// Greedy in-order row packing at a candidate uniform row height: walk the
// tiles, start a new row whenever the next tile would overflow the width.
// Returns the row count, or Infinity if a single tile is wider than the row.
function rowsAtHeight(aspects, containerWidth, gap, height) {
  let rows = 1;
  let rowWidth = 0;

  for (const aspect of aspects) {
    const tileWidth = height * aspect;
    if (tileWidth > containerWidth) {
      return Infinity;
    }

    const needed = rowWidth === 0 ? tileWidth : gap + tileWidth;
    if (rowWidth + needed > containerWidth) {
      rows += 1;
      rowWidth = tileWidth;
    } else {
      rowWidth += needed;
    }
  }

  return rows;
}

// Largest uniform row height at which all tiles — each rendered at its own
// aspect ratio (width = height * aspect) — fit the container, packed into rows.
// Tiles share a height and vary in width, so portrait and landscape feeds sit
// side by side without cropping or distortion. For a room where every tile has
// the same aspect this converges to the same optimum as a column-count search;
// mixed-aspect rooms get a justified-gallery layout. The grid uses
// `contain: size`, so the result never feeds back into the container size —
// without it, oversized tiles (e.g. right after exiting fullscreen) would
// grow the grid, the remeasure would see the inflated box, and the layout
// would lock there.
export function bestRowHeight(containerWidth, containerHeight, aspects, gap) {
  const count = aspects.length;
  if (!count || containerWidth <= 0 || containerHeight <= 0) {
    return 0;
  }

  const fits = (height) => {
    const rows = rowsAtHeight(aspects, containerWidth, gap, height);
    if (!isFinite(rows)) {
      return false;
    }
    return rows * height + (rows - 1) * gap <= containerHeight;
  };

  let low = 0;
  let high = containerHeight;
  for (let i = 0; i < 40; i++) {
    const mid = (low + high) / 2;
    if (fits(mid)) {
      low = mid;
    } else {
      high = mid;
    }
  }

  // The search converges from just below the true maximum, so flooring can
  // shed the last pixel at an exact boundary (e.g. one tile in a container of
  // its own height). Reclaim it when the rounded-up height still fits.
  const rowHeight = Math.floor(low);
  return fits(rowHeight + 1) ? rowHeight + 1 : rowHeight;
}

// The widget grid trades the room page's per-tile aspect fidelity for uniform
// tiles that pack a small box predictably; cover-cropping absorbs the
// difference between a feed's real aspect and the cell's.
const WIDGET_TILE_MIN_ASPECT = 4 / 3;

// Smallest tile that still reads at a glance: avatar, name, status icons.
const WIDGET_TILE_MIN_WIDTH = 88;
const WIDGET_TILE_MIN_HEIGHT = 66;

// Visual ceiling for the widget. Past this a floating mini-view stops being
// glanceable no matter how much space it has; the room page is the place for
// big grids.
const WIDGET_MAX_SLOTS = 12;

// Largest uniform tile for `slots` tiles in a width×height box: try every
// column count, size the cell, clamp the tile's aspect to the allowed band,
// keep the arrangement with the biggest tile. Ties prefer more columns — when
// tiles are height-constrained a wider grid uses the slack width, and it
// makes an unfloored tile width that fits `cols + 1` per line impossible
// (that arrangement would have scored at least as high and won the tie).
function bestGridForSlots(slots, width, height, gap) {
  let best = null;

  for (let cols = 1; cols <= slots; cols++) {
    const rows = Math.ceil(slots / cols);
    const cellWidth = (width - (cols - 1) * gap) / cols;
    const cellHeight = (height - (rows - 1) * gap) / rows;
    if (cellWidth <= 0 || cellHeight <= 0) {
      continue;
    }

    const aspect = Math.min(
      Math.max(cellWidth / cellHeight, WIDGET_TILE_MIN_ASPECT),
      DEFAULT_TILE_ASPECT
    );
    const tileWidth = Math.min(cellWidth, cellHeight * aspect);
    const tileHeight = tileWidth / aspect;
    const area = tileWidth * tileHeight;

    if (!best || area >= best.area) {
      best = { cols, rows, tileWidth, tileHeight, area };
    }
  }

  return best;
}

// Uniform grid for the floating call widget: show as many participants as fit
// above the legibility floor, and collapse the rest into one overflow slot
// (rendered as a "+N" tile). The search walks candidate slot counts downward —
// fewer slots mean bigger tiles — and returns the first arrangement whose
// tiles clear the floor, so the tile size adapts to the box and the crowd
// instead of a fixed column template. When the box is too small for even two
// legible slots, the floor yields rather than the tiles vanishing. Overflow is
// never exactly one: a "+1" tile would spend the slot the hidden person could
// have used, so the smallest overflow absorbs two.
export function computeWidgetGrid({ width, height, count, gap }) {
  if (!count || width <= 0 || height <= 0) {
    return null;
  }

  const minSlots = Math.min(count, 2);
  let fallback = null;

  for (
    let slots = Math.min(count, WIDGET_MAX_SLOTS);
    slots >= minSlots;
    slots--
  ) {
    const grid = bestGridForSlots(slots, width, height, gap);
    if (!grid) {
      continue;
    }

    const shown = slots === count ? count : slots - 1;

    // Flooring to whole pixels can shed just enough width that cols + 1 tiles
    // squeeze onto one flex line, breaking the solved grid. The unfloored
    // width never fits an extra tile (see bestGridForSlots), so when the
    // floored one does, nudge it back above that threshold — fractional, and
    // still below the width that was proven to fit.
    let tileWidth = Math.floor(grid.tileWidth);
    const extraTileLimit = (width - grid.cols * gap) / (grid.cols + 1);
    if (tileWidth <= extraTileLimit) {
      tileWidth = (extraTileLimit + grid.tileWidth) / 2;
    }

    const layout = {
      shown,
      overflow: count - shown,
      cols: grid.cols,
      rows: grid.rows,
      tileWidth,
      tileHeight: Math.floor(grid.tileHeight),
    };

    if (
      grid.tileWidth >= WIDGET_TILE_MIN_WIDTH &&
      grid.tileHeight >= WIDGET_TILE_MIN_HEIGHT
    ) {
      return layout;
    }

    fallback = layout;
  }

  return fallback;
}

// Reports the grid's content box (and resolved gap) to `onResize` whenever it
// changes, so the layout can be recomputed for the available space.
export const trackGridSize = modifier((element, [onResize]) => {
  const observer = new ResizeObserver((entries) => {
    const { width, height } = entries[0].contentRect;
    const gap = parseFloat(getComputedStyle(element).rowGap) || 0;
    onResize(width, height, gap);
  });
  observer.observe(element);
  return () => observer.disconnect();
});

// Reports a media element's intrinsic aspect ratio (width / height) to
// `onAspect` once metadata loads and again whenever it changes — e.g. a phone
// rotating mid-call fires `resize`. Reports null on teardown so the consumer
// can fall back to the default for an avatar tile.
export const trackVideoAspect = modifier((element, [onAspect]) => {
  const report = () => {
    const { videoWidth, videoHeight } = element;
    if (videoWidth > 0 && videoHeight > 0) {
      onAspect(videoWidth / videoHeight);
    }
  };

  element.addEventListener("loadedmetadata", report);
  element.addEventListener("resize", report);
  report();

  return () => {
    element.removeEventListener("loadedmetadata", report);
    element.removeEventListener("resize", report);
    onAspect(null);
  };
});
