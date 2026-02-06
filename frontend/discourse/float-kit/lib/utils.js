/**
 * Check if element is a clone (used during focus scroll prevention).
 *
 * @param {Element} element
 * @returns {boolean}
 */
export function isCloneElement(element) {
  return element?.getAttribute("data-d-scroll-clone") === "true";
}

