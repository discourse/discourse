/**
 * Convert track direction to content placement.
 *
 * @param {string} track
 * @returns {string}
 */
export function trackToPlacement(track) {
  switch (track) {
    case "top":
    case "left":
      return "start";
    case "bottom":
    case "right":
      return "end";
    case "horizontal":
    case "vertical":
      return "center";
    default:
      return "end";
  }
}
