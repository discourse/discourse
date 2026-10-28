import { modifier } from "ember-modifier";

// Fallback aspect (width / height) for tiles whose media hasn't reported its
// intrinsic size yet, and for avatar-only tiles. Matches a landscape camera.
export const DEFAULT_TILE_ASPECT = 16 / 9;

// Both grids use uniform tiles rather than each feed's own aspect: a stage is
// rarely a multiple of 16:9, so aspect-faithful tiles leave large empty bands
// at most participant counts. Cover-cropping absorbs the difference between a
// feed's real aspect and the cell's, within each grid's aspect band.

// Widest cell a tile may take: a wider one would crop the top and bottom of a
// landscape camera, where the head is.
const TILE_MAX_ASPECT = DEFAULT_TILE_ASPECT;

// Every column count's uniform tile for `slots` tiles in a width×height box:
// size the cell, clamp the tile's aspect to the band, fit the tile in the cell.
function gridCandidates(slots, width, height, gap, minAspect) {
  const candidates = [];

  for (let cols = 1; cols <= slots; cols++) {
    const rows = Math.ceil(slots / cols);
    const cellWidth = (width - (cols - 1) * gap) / cols;
    const cellHeight = (height - (rows - 1) * gap) / rows;
    if (cellWidth <= 0 || cellHeight <= 0) {
      continue;
    }

    const aspect = Math.min(
      Math.max(cellWidth / cellHeight, minAspect),
      TILE_MAX_ASPECT
    );
    const tileWidth = Math.min(cellWidth, cellHeight * aspect);
    const tileHeight = tileWidth / aspect;

    candidates.push({
      cols,
      rows,
      tileWidth,
      tileHeight,
      area: tileWidth * tileHeight,
      emptySlots: cols * rows - slots,
    });
  }

  return candidates;
}

// A webcam frame keeps the face near the center, so the room page can crop
// down to square cells, which lets a landscape stage fit more columns.
const ROOM_TILE_MIN_ASPECT = 1;

// A slightly smaller tile is a better trade than a ragged last row.
const ROOM_FULL_ROW_TOLERANCE = 0.92;

// Uniform grid for the room page: the largest tile for `count` tiles, except
// that an arrangement with fewer empty slots wins when its tile is within
// tolerance of the largest. `lineWidth` caps the tile container so flex
// wrapping breaks exactly at `cols` — the preferred arrangement isn't always
// the largest one, so an uncapped line could fit an extra tile.
export function computeRoomGrid({ width, height, count, gap }) {
  if (!count || width <= 0 || height <= 0) {
    return null;
  }

  const candidates = gridCandidates(
    count,
    width,
    height,
    gap,
    ROOM_TILE_MIN_ASPECT
  );
  if (!candidates.length) {
    return null;
  }

  const largest = Math.max(...candidates.map((grid) => grid.area));
  const best = candidates
    .filter((grid) => grid.area >= largest * ROOM_FULL_ROW_TOLERANCE)
    .reduce((a, b) =>
      b.emptySlots < a.emptySlots ||
      (b.emptySlots === a.emptySlots && b.area > a.area)
        ? b
        : a
    );

  const tileWidth = Math.floor(best.tileWidth);

  return {
    cols: best.cols,
    rows: best.rows,
    tileWidth,
    tileHeight: Math.floor(best.tileHeight),
    // One spare pixel absorbs subpixel rounding in the flex line; it can never
    // admit another tile.
    lineWidth: best.cols * tileWidth + (best.cols - 1) * gap + 1,
  };
}

// The widget stays closer to the feed's own framing than the room page.
const WIDGET_TILE_MIN_ASPECT = 4 / 3;

// Smallest tile that still reads at a glance: avatar, name, status icons.
const WIDGET_TILE_MIN_WIDTH = 88;
const WIDGET_TILE_MIN_HEIGHT = 66;

// Visual ceiling for the widget. Past this a floating mini-view stops being
// glanceable no matter how much space it has; the room page is the place for
// big grids.
const WIDGET_MAX_SLOTS = 12;

// Largest uniform tile for `slots` tiles. Ties prefer more columns — when
// tiles are height-constrained a wider grid uses the slack width, and it
// makes an unfloored tile width that fits `cols + 1` per line impossible
// (that arrangement would have scored at least as high and won the tie).
function bestGridForSlots(slots, width, height, gap) {
  let best = null;

  for (const grid of gridCandidates(
    slots,
    width,
    height,
    gap,
    WIDGET_TILE_MIN_ASPECT
  )) {
    if (!best || grid.area >= best.area) {
      best = grid;
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
