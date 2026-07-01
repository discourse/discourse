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
export function toKebabCase(property) {
  const prefix =
    property.startsWith("webkit") || property.startsWith("moz") ? "-" : "";
  return prefix + property.replace(/[A-Z]/g, "-$&").toLowerCase();
}
