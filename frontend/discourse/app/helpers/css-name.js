/**
 * Converts a block or outlet name to a valid CSS class name segment.
 * Replaces colons (from namespacing) with hyphens.
 *
 * @param {string} name - The block or outlet name (may contain colons).
 * @returns {string} A CSS-safe name with colons replaced by hyphens.
 */
export default function cssName(name = "") {
  return name.replace(/:/g, "-");
}
