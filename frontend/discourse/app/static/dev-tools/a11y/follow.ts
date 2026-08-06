/**
 * How close to the bottom still counts as being at it.
 *
 * `scrollHeight - scrollTop - clientHeight` is rarely exactly zero — fractional
 * device pixel ratios, subpixel row heights and browser rounding all leave a
 * remainder — so an equality test against zero reads as "detached" while the
 * reader is visibly pinned to the bottom.
 */
export const BOTTOM_TOLERANCE_PX = 4;

export interface ScrollMetrics {
  readonly scrollTop: number;
  readonly scrollHeight: number;
  readonly clientHeight: number;
}

/**
 * Whether a scroller is pinned to its newest row, and so should keep following it.
 * A list shorter than its viewport counts as pinned.
 */
export function isAtBottom(
  metrics: ScrollMetrics,
  tolerance: number = BOTTOM_TOLERANCE_PX
): boolean {
  if (metrics.scrollHeight <= metrics.clientHeight) {
    return true;
  }

  return (
    metrics.scrollHeight - metrics.scrollTop - metrics.clientHeight <= tolerance
  );
}
