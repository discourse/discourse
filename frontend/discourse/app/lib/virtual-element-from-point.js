/**
 * Creates a zero-size reference at a fixed viewport point.
 *
 * @param {number} x - The viewport x coordinate.
 * @param {number} y - The viewport y coordinate.
 * @returns {import("@floating-ui/dom").VirtualElement}
 */
export default function virtualElementFromPoint(x, y) {
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
