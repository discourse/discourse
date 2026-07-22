// Editor-only geometry for WRAPPING flow drop resolution (tiles, and rows whose
// children wrap onto multiple visual lines). Pure data, no DOM — the caller
// hands in each child's bounding rect and the cursor, so the math is trivially
// unit-testable.
//
// The 1-D `resolveLinearDrop` can't target a wrapped container: it compares only
// the cursor's main-axis coordinate, so a child on line 2 shares the main-axis
// band of the child above it and the drop lands in the wrong gap. This resolver
// first groups the children into visual BANDS (lines) along the cross axis, picks
// the band under the cursor, then delegates the within-band decision to the
// unchanged `resolveLinearDrop`. A single band reduces to exactly that call, so
// unwrapped containers behave identically to before.

import {
  resolveLinearDrop,
  type Segment,
} from "discourse/plugins/discourse-wireframe/discourse/lib/linear-drop";

/**
 * A child's bounding box (viewport coordinates), as returned by
 * `getBoundingClientRect()`.
 */
export type Rect = {
  /** Left edge in viewport coordinates. */
  left: number;
  /** Right edge in viewport coordinates. */
  right: number;
  /** Top edge in viewport coordinates. */
  top: number;
  /** Bottom edge in viewport coordinates. */
  bottom: number;
};

/**
 * Where to paint the boundary tick: `x` is the tick's horizontal center and
 * `top`/`bottom` are the target band's vertical extent, so the tick spans only
 * the line the cursor is on rather than the whole container. Present only for
 * `gap` results in a genuinely wrapped (multi-band) container.
 */
export type Indicator = {
  /** Horizontal center of the boundary tick. */
  x: number;
  /** Top of the target visual band. */
  top: number;
  /** Bottom of the target visual band. */
  bottom: number;
};

/** A boundary landing in a wrapping flow. */
type WrappingFlowGapDrop = {
  /** Identifies a boundary landing. */
  kind: "gap";
  /** Boundary index in the flat child list. */
  gap: number;
  /** Tick geometry when the container has multiple visual bands. */
  indicator?: Indicator;
};

/** A landing in the middle third of a wrapping-flow child. */
type WrappingFlowMiddleDrop = {
  /** Identifies a child-middle landing. */
  kind: "middle";
  /** Index in the flat child list. */
  index: number;
};

/**
 * The resolved landing: the SAME shape as `resolveLinearDrop`'s result, plus an
 * optional `indicator` on `gap` results (present only when the container wraps).
 */
export type WrappingFlowDropResult =
  | WrappingFlowGapDrop
  | WrappingFlowMiddleDrop;

// The two rect edges that bound a child along a given axis, named as keys of
// `Rect`, so `rect[edges.near]` / `rect[edges.far]` project onto that axis.
type AxisEdges = {
  /** Rect edge at the start of the axis. */
  near: keyof Rect;
  /** Rect edge at the end of the axis. */
  far: keyof Rect;
};

// An axis projection: which rect edges bound the child on this axis, plus the
// cursor's coordinate on the same axis.
type AxisProjection = AxisEdges & {
  /** Cursor coordinate on the projected axis. */
  coord: number;
};

// A visual line: the contiguous DOM-index run of children sharing a cross-axis
// band, plus the band's cross-axis extent (`near`/`far` as numbers here).
type Band = {
  /** Index of the band's first child in the flat list. */
  startIndex: number;
  /** Flat child indexes belonging to the band. */
  indices: number[];
  /** Leading edge on the cross axis. */
  near: number;
  /** Trailing edge on the cross axis. */
  far: number;
};

// Pixel slack when testing whether a child belongs to the current band. Two
// children on the same visual line overlap heavily on the cross axis; a child
// that starts at or past the band's far edge begins a new line. The slack
// tolerates sub-pixel layout rounding without merging distinct lines.
const BAND_OVERLAP_EPSILON = 1;

/**
 * Resolves where a 2-D cursor lands among wrapping flow children.
 *
 * Returns the SAME shape as `resolveLinearDrop` so the caller's existing gap /
 * middle handling is reused unchanged, with two additions: the boundary index is
 * GLOBAL (into the flat DOM-order child list, not band-local), and a `gap` result
 * carries an `indicator` when the container actually wraps.
 *
 *  - `{ kind: "gap", gap, indicator? }` — a boundary at global index `gap` in
 *    `[0 .. rects.length]`. `indicator` is present only for multi-band containers.
 *  - `{ kind: "middle", index }` — the cursor sits in the middle third of the
 *    child at global `index`; the caller classifies it (INSIDE / REPLACE / none).
 *
 * @param rects - Child bounding rects in DOM order.
 * @param cursor - The cursor position.
 * @param options - The flow's main axis. `"x"` (default) is a horizontal flow
 *   that wraps into vertical lines (rows / tiles).
 * @returns The resolved global landing and optional wrapped-band indicator.
 */
export function resolveWrappingFlowDrop(
  rects: Rect[],
  cursor: {
    /** Cursor x-coordinate in viewport pixels. */
    x: number;
    /** Cursor y-coordinate in viewport pixels. */
    y: number;
  },
  {
    mainAxis = "x",
  }: {
    /** Axis along which children flow before wrapping. */
    mainAxis?: "x" | "y";
  } = {}
): WrappingFlowDropResult {
  const children = rects ?? [];

  // Empty container — mirror `resolveLinearDrop`'s contract so the caller's
  // empty-container path (paint over the empty-state placeholder) fires.
  if (children.length === 0) {
    return { kind: "gap", gap: 0 };
  }

  // Project the main/cross axes onto concrete rect edges. For a horizontal flow
  // the main axis is x (children flow left→right) and lines stack along y.
  const main: AxisProjection =
    mainAxis === "x"
      ? { near: "left", far: "right", coord: cursor.x }
      : { near: "top", far: "bottom", coord: cursor.y };
  const cross: AxisProjection =
    mainAxis === "x"
      ? { near: "top", far: "bottom", coord: cursor.y }
      : { near: "left", far: "right", coord: cursor.x };

  const bands = groupIntoBands(children, cross);

  // A single band means the container isn't wrapped: delegate straight to the
  // 1-D resolver over every child, with no indicator, so the result (dispatch
  // AND geometry) is byte-identical to the pre-wrapping behavior.
  if (bands.length === 1) {
    return resolveLinearDrop(mainSegments(children, main), main.coord);
  }

  const band = pickBand(bands, cross.coord);
  const bandRects = band.indices.map((i) => children[i]);
  const local = resolveLinearDrop(mainSegments(bandRects, main), main.coord);

  if (local.kind === "middle") {
    return { kind: "middle", index: band.startIndex + local.index };
  }

  const gap = band.startIndex + local.gap;
  return {
    kind: "gap",
    gap,
    indicator: bandIndicator(bandRects, local.gap, band, main),
  };
}

/**
 * Projects each rect onto the main axis into the `{near, far}` segments
 * `resolveLinearDrop` expects.
 *
 * @param rects - Child rectangles in DOM order.
 * @param main - Rect edges defining the main axis.
 * @returns One linear segment per rectangle.
 */
function mainSegments(rects: Rect[], main: AxisEdges): Segment[] {
  return rects.map((rect) => ({ near: rect[main.near], far: rect[main.far] }));
}

/**
 * Groups children (in DOM order) into visual bands along the cross axis. A child
 * joins the current band when it OVERLAPS the band's cross-axis extent; it starts
 * a new band when it begins at or past the band's far edge. Overlap (not a
 * midpoint test) keeps a single line of mixed-height children in one band.
 *
 * Because flow is line-major, bands are contiguous DOM-index runs, so a band's
 * `startIndex` plus a within-band index maps straight back to a global index.
 *
 * @param rects - Child rectangles in DOM order.
 * @param cross - Rect edges defining the cross axis.
 * @returns Visual bands in DOM order.
 */
function groupIntoBands(rects: Rect[], cross: AxisEdges): Band[] {
  const bands: Band[] = [];
  let current: Band | null = null;

  rects.forEach((rect, index) => {
    const near = rect[cross.near];
    const far = rect[cross.far];
    // Overlaps the current band when it starts before the band's far edge.
    if (current && near < current.far - BAND_OVERLAP_EPSILON) {
      current.indices.push(index);
      current.near = Math.min(current.near, near);
      current.far = Math.max(current.far, far);
    } else {
      current = { startIndex: index, indices: [index], near, far };
      bands.push(current);
    }
  });

  return bands;
}

/**
 * Picks the band the cursor is in, or the nearest one when the cursor sits in an
 * inter-band gutter or beyond the ends. Ties resolve to the later (further along
 * the cross axis) band, so a cursor exactly on a seam prefers the lower row.
 *
 * @param bands - Candidate visual bands.
 * @param coord - The cursor's cross-axis coordinate.
 * @returns The containing or nearest visual band.
 */
function pickBand(bands: Band[], coord: number): Band {
  let best = bands[0];
  let bestDistance = Infinity;
  for (const band of bands) {
    // Zero when inside the band's extent, otherwise distance to the nearest edge.
    const distance =
      coord < band.near
        ? band.near - coord
        : coord > band.far
          ? coord - band.far
          : 0;
    // `<=` lets a later band win a tie (equal distance), preferring the lower row.
    if (distance <= bestDistance) {
      best = band;
      bestDistance = distance;
    }
  }
  return best;
}

/**
 * Builds the boundary indicator for a within-band gap: a tick spanning the band's
 * cross-axis extent, centered on the in-band edge of the neighbouring child(ren).
 *
 * @param bandRects - The band's rects, in DOM order.
 * @param localGap - The gap index within the band, in `[0 .. length]`.
 * @param band - The band's cross-axis extent.
 * @param main - Rect edges defining the main axis.
 * @returns Geometry for the boundary tick.
 */
function bandIndicator(
  bandRects: Rect[],
  localGap: number,
  band: Pick<Band, "near" | "far">,
  main: AxisEdges
): Indicator {
  let x: number;
  if (localGap === 0) {
    // Before the first child of the line — the line's leading edge.
    x = bandRects[0][main.near];
  } else if (localGap === bandRects.length) {
    // After the last child of the line — the line's trailing edge.
    x = bandRects[bandRects.length - 1][main.far];
  } else {
    // Between two children on the same line — the midpoint of their gap.
    x =
      (bandRects[localGap - 1][main.far] + bandRects[localGap][main.near]) / 2;
  }
  return { x, top: band.near, bottom: band.far };
}
