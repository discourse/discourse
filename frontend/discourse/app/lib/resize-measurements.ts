import type { Axis } from "discourse/lib/geometry";
import { headerOffset } from "discourse/lib/offset-calculator";

/** The axis a resize runs along. */
export type ResizeAxis = Axis;

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
  vertical: { computed: "height", min: "minHeight", max: "maxHeight" },
  horizontal: { computed: "width", min: "minWidth", max: "maxWidth" },
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
 * The box's current extent along the axis being resized, read from the same box
 * that `style.height` and `style.width` write.
 *
 * Those properties set the content box under `content-box` and the border box
 * under `border-box`. `offsetHeight` is right only in the second case, so a
 * bordered `content-box` element drifts a little on every gesture.
 *
 * Null when there is nothing to measure, which a resize would otherwise drag on
 * from. `pixels` enforces that. An element with no box keeps whatever was
 * declared, and a percentage would parse into a plausible-looking number.
 */
export function measuredSize(
  element: HTMLElement | null | undefined,
  axis: ResizeAxis
): number | null {
  if (!element?.isConnected) {
    return null;
  }

  return pixels(getComputedStyle(element)[AXIS_PROPERTIES[axis].computed]);
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
 * What is left of the viewport, leaving the header its space.
 *
 * This suits a box pinned in the viewport, which would otherwise grow out of
 * view. A box in a scrolling page only lengthens the page, so this caps it for
 * no reason. Such a consumer should pass its own maximum.
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
 * The largest the box may be dragged to. A declared maximum binds, so dragging
 * past it would report a size never rendered, and `cap` binds above that.
 *
 * Never below {@link measuredMin}. A short viewport can put the cap under the
 * declared minimum, and CSS lets the minimum win. Announcing a maximum beneath
 * it would promise a range the box cannot take.
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
  const capped = declared === null ? cap : Math.min(declared, cap);
  return Math.max(capped, measuredMin(element, axis));
}
