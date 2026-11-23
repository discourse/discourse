import { trustHTML } from "@ember/template";

/**
 * Bars for a 1-bit chart. Each bar's width and dither density both follow its share of the
 * largest value, so a denser pattern always means more.
 *
 * @param {Array<Object>} items
 * @param {string} valueKey - The property holding each item's value.
 * @returns {Array<Object>} The items with their `share` of the largest value, a `density`
 * (1 to 8) and a width `style`.
 */
export function barsFor(items, valueKey = "count") {
  const max = Math.max(1, ...items.map((item) => item[valueKey]));

  return items.map((item) => {
    const share = item[valueKey] / max;
    return {
      ...item,
      share,
      density: Math.max(1, Math.round(share * 8)),
      style: trustHTML(`width: ${(share * 100).toFixed(2)}%`),
    };
  });
}
