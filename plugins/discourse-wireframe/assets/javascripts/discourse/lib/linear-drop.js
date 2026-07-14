// @ts-check
// Editor-only geometry for linear (stack / row) drop resolution. Pure data,
// no DOM — the caller projects each child's bounding rect onto the active
// axis into `{ near, far }` numbers and hands them here, so the math is
// trivially unit-testable.

/**
 * @typedef {{near: number, far: number}} Segment
 *   A child's extent along the active axis. For a vertical stack `near`/`far`
 *   are the child's top/bottom; for a horizontal row they're its left/right.
 */

/**
 * Resolves where a cursor at `cursor` (a single axis coordinate) would land
 * among an ordered list of sibling `segments`.
 *
 * The result is one of:
 *
 *  - `{ kind: "gap", gap }` — the cursor sits at a BOUNDARY between siblings.
 *    `gap` is a boundary index in `[0 .. segments.length]`: `0` is the start
 *    (before the first child), `segments.length` is the end (after the last
 *    child), and any value in between is the interior boundary separating
 *    `segments[gap - 1]` from `segments[gap]`.
 *  - `{ kind: "middle", index }` — the cursor sits in the middle third of
 *    `segments[index]`. The caller decides what that means (drop INSIDE a
 *    container, REPLACE a slot, or nothing for a leaf) since this module
 *    doesn't know block types.
 *
 * The boundary index is the key to collapsing the old "after A" / "before B"
 * pair into a single zone. A cursor in the LAST third of `segments[i]` and a
 * cursor in the FIRST third of `segments[i + 1]` (and the gap between them)
 * all resolve to the SAME `gap` value (`i + 1`), so both sides of an interior
 * boundary produce one descriptor instead of two competing ones.
 *
 * @param {Array<Segment>} segments - Ordered child extents along the axis.
 * @param {number} cursor - The cursor's coordinate on the same axis.
 * @returns {{kind: "gap", gap: number} | {kind: "middle", index: number}}
 */
export function resolveLinearDrop(segments, cursor) {
  const children = segments ?? [];

  // Empty container — the only landing is "into" it, expressed as the start
  // boundary so the caller can treat it uniformly with other gaps.
  if (children.length === 0) {
    return { kind: "gap", gap: 0 };
  }

  // Find the first child whose far edge is past the cursor. That child is the
  // candidate the cursor is either inside of, or in the gap before.
  let landingIndex = children.length;
  for (let i = 0; i < children.length; i++) {
    if (cursor < children[i].far) {
      landingIndex = i;
      break;
    }
  }

  // Cursor is past every child → the end boundary.
  if (landingIndex === children.length) {
    return { kind: "gap", gap: children.length };
  }

  const { near, far } = children[landingIndex];

  // Cursor sits in the gap before this child → the boundary at `landingIndex`.
  if (cursor < near) {
    return { kind: "gap", gap: landingIndex };
  }

  // Cursor is inside the child — split it into thirds.
  const size = far - near;
  const offset = cursor - near;
  const third = size / 3;

  // First third → boundary BEFORE this child (`landingIndex`).
  if (offset < third) {
    return { kind: "gap", gap: landingIndex };
  }
  // Last third → boundary AFTER this child (`landingIndex + 1`). This is what
  // makes "after A" canonicalize to the same boundary as "before B".
  if (offset > size - third) {
    return { kind: "gap", gap: landingIndex + 1 };
  }
  // Middle third — caller classifies by block type.
  return { kind: "middle", index: landingIndex };
}
