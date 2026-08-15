import { headerOffset } from "discourse/lib/offset-calculator";

/** The axis a resize runs along. */
export type ResizeAxis = "vertical" | "horizontal";

/**
 * Floor for a box whose minimum does not resolve to pixels, per axis.
 *
 * Not one constant: a flex item computes `auto` on both axes and a horizontal
 * splitter usually resizes one, so that floor binds far more often.
 */
const DEFAULT_MIN_SIZE: Record<ResizeAxis, number> = {
  vertical: 250,
  horizontal: 100,
};

/** Which properties describe a box's extent along each axis. */
const AXIS_PROPERTIES = {
  vertical: { offset: "offsetHeight", min: "minHeight", max: "maxHeight" },
  horizontal: { offset: "offsetWidth", min: "minWidth", max: "maxWidth" },
} as const;

/**
 * A computed length in pixels, or `null` when it is not one.
 *
 * Both checks are load-bearing. CSSOM leaves these properties' percentages
 * unresolved and `50%` parses to a plausible `50`, which only the unit catches;
 * `calc(10% + 5px)` ends in `px`, which only the parse catches.
 */
function pixels(declared: string | undefined): number | null {
  if (!declared?.endsWith("px")) {
    return null;
  }

  const value = parseFloat(declared);
  return Number.isFinite(value) ? value : null;
}

/**
 * The box's current extent along the axis being resized, from its border box.
 *
 * Null rather than zero when there is nothing to measure, which a resize would
 * read as a real extent and drag on from. A detached box reports zero, so it
 * counts as unmeasured too.
 */
export function measuredSize(
  element: HTMLElement | null | undefined,
  axis: ResizeAxis
): number | null {
  if (!element?.isConnected) {
    return null;
  }

  return element[AXIS_PROPERTIES[axis].offset];
}

/**
 * The smallest the box may be dragged to, read from the stylesheet so the two
 * cannot drift apart. Zero with no box to measure: the floor stands in for an
 * unresolved minimum, not for an absent consumer.
 */
export function measuredMin(
  element: HTMLElement | null | undefined,
  axis: ResizeAxis
): number {
  if (!element?.isConnected) {
    return 0;
  }

  return (
    pixels(getComputedStyle(element)[AXIS_PROPERTIES[axis].min]) ??
    DEFAULT_MIN_SIZE[axis]
  );
}

/**
 * What is left of the viewport, leaving the header its space, which is as far as
 * a box can grow.
 *
 * Asymmetric on purpose: `clientWidth` drops the scrollbar gutter while
 * `innerHeight` keeps it, and matching them would move behaviour that shipped.
 */
export function viewportCap(axis: ResizeAxis): number {
  return axis === "horizontal"
    ? document.documentElement.clientWidth
    : window.innerHeight - headerOffset();
}

/**
 * The largest the box may be dragged to, never above `cap`. A declared maximum
 * binds too, so dragging past it would report a size never rendered.
 */
export function measuredMax(
  element: HTMLElement | null | undefined,
  axis: ResizeAxis,
  cap: number = viewportCap(axis)
): number {
  if (!element?.isConnected) {
    return cap;
  }

  const declared = pixels(getComputedStyle(element)[AXIS_PROPERTIES[axis].max]);
  return declared === null ? cap : Math.min(declared, cap);
}
