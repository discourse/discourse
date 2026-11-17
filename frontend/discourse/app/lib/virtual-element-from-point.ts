import type { VirtualElement } from "@floating-ui/dom";

/**
 * Creates a zero-size reference at a fixed viewport point.
 *
 * Deliberately carries no `contextElement`: setting one moves the clipping boundary to that
 * element's overflow ancestors and reintroduces a scale divisor, neither of which a point
 * anchored to the viewport wants.
 *
 * @param x - The viewport x coordinate.
 * @param y - The viewport y coordinate.
 */
export default function virtualElementFromPoint(
  x: number,
  y: number
): VirtualElement {
  return {
    getBoundingClientRect() {
      return {
        x,
        y,
        left: x,
        right: x,
        top: y,
        bottom: y,
        width: 0,
        height: 0,
      };
    },
  };
}
