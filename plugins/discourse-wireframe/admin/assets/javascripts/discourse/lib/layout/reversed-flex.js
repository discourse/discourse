// @ts-check

/**
 * Whether a layout block's args describe a REVERSED flex layout (stack or row
 * with `reverse: true`). Such layouts render their children in reversed DOM
 * order while the persisted `children` array stays in author order, so any
 * ordering operation computed from VISUAL order (a drop's before/after, a
 * visual "move up") must be flipped to land correctly in the persisted array.
 *
 * Grid / tiles never reverse (grid is placement-sorted), so this is gated to
 * the two flex modes. The legacy `"free-grid"` mode coerces to grid.
 *
 * @param {Object|null|undefined} args - A layout block entry's `args`.
 * @returns {boolean}
 */
export function isReversedFlexLayout(args) {
  if (!args?.reverse) {
    return false;
  }
  const mode = args.mode === "free-grid" ? "grid" : (args.mode ?? "stack");
  return mode === "stack" || mode === "row";
}

/**
 * Flips a relative insert position. Used to map a VISUAL before/after onto the
 * persisted array when the container is a reversed flex layout.
 *
 * @param {"before"|"after"} position
 * @returns {"before"|"after"}
 */
export function flipPosition(position) {
  return position === "before" ? "after" : "before";
}
