/**
 * CSS transform properties that should be combined into a single transform string.
 *
 * @type {Set<string>}
 */
export const TRANSFORM_PROPS = new Set([
  "translate",
  "translateX",
  "translateY",
  "translateZ",
  "scale",
  "scaleX",
  "scaleY",
  "scaleZ",
  "rotate",
  "rotateX",
  "rotateY",
  "rotateZ",
  "skew",
  "skewX",
  "skewY",
]);

/**
 * Converts a camelCase CSS property to kebab-case with vendor prefix handling.
 *
 * @param {string} property - camelCase property name
 * @returns {string} kebab-case property name
 */
export function toKebabCase(property) {
  const prefix =
    property.startsWith("webkit") || property.startsWith("moz") ? "-" : "";
  return prefix + property.replace(/[A-Z]/g, "-$&").toLowerCase();
}
