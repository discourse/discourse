/** Layout arguments used to determine visual child ordering. */
type ReversibleLayoutArgs = {
  /** The layout mode. */
  mode?: unknown;

  /** Whether flex children render in reverse order. */
  reverse?: unknown;
};

/** A position relative to a sibling entry. */
export type RelativePosition = "before" | "after";

/**
 * Whether a layout block's args describe a REVERSED flex layout (stack or row
 * with `reverse: true`). Such layouts render their children in reversed DOM
 * order while the persisted `children` array stays in author order, so any
 * ordering operation computed from VISUAL order (a drop's before/after, a
 * visual "move up") must be flipped to land correctly in the persisted array.
 *
 * Grid never reverses (it is placement-sorted), so this is gated to
 * the two flex modes. The legacy `"free-grid"` mode coerces to grid.
 *
 * @param args - A layout block entry's arguments.
 */
export function isReversedFlexLayout(
  args: ReversibleLayoutArgs | null | undefined
): boolean {
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
 * @param position - The visual position to translate.
 * @returns The corresponding position in persisted child order.
 */
export function flipPosition(position: RelativePosition): RelativePosition {
  return position === "before" ? "after" : "before";
}
