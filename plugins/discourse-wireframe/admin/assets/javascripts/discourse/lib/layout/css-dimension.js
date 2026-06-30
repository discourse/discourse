// @ts-check
/**
 * Pure parse / format helpers for CSS dimension values (a number plus an
 * optional unit, e.g. `16px`, `1.5rem`, `50%`). The dimension control splits
 * a stored value into its numeric and unit parts for two separate inputs, then
 * reassembles them on every edit — these helpers are that split / join, kept
 * free of Glimmer so they can be unit-tested in isolation.
 *
 * Two value shapes flow through here:
 *   - a bare `Number` (a "unitless" dimension, e.g. the layout gap stored as a
 *     plain rem count), and
 *   - a CSS string like `"16rem"` (the shape `minItemWidth` / `rowHeight` use).
 *
 * `parseDimension` accepts either; the caller decides which shape to write back
 * via `formatDimension`.
 */

// One optional sign, an integer or decimal, then an optional unit token
// (letters or `%`). Leading / trailing whitespace is tolerated.
const DIMENSION_PATTERN = /^\s*(-?\d*\.?\d+)\s*([a-z%]*)\s*$/i;

/**
 * Splits a dimension value into its numeric and unit parts.
 *
 * @param {string|number|null|undefined} raw - A CSS dimension string
 *   (`"16rem"`), a bare number, or a nullish / unparseable value.
 * @returns {{value: number, unit: string}|null} `{ value, unit }` with a finite
 *   number and a (possibly empty) unit string, or `null` when `raw` is nullish,
 *   empty, or not a simple `<number><unit>` value (e.g. `"auto"`,
 *   `"minmax(80px, auto)"`).
 */
export function parseDimension(raw) {
  if (raw == null) {
    return null;
  }

  if (typeof raw === "number") {
    return Number.isFinite(raw) ? { value: raw, unit: "" } : null;
  }

  if (typeof raw !== "string") {
    return null;
  }

  const match = raw.match(DIMENSION_PATTERN);
  if (!match) {
    return null;
  }

  const value = parseFloat(match[1]);
  if (!Number.isFinite(value)) {
    return null;
  }

  return { value, unit: match[2] ?? "" };
}

/**
 * Reassembles a numeric value and a unit into the value to persist.
 *
 * Passing an empty `unit` returns the bare `Number` (the unitless shape — the
 * caller stores `1`, not `"1"`), so a unitless control round-trips without ever
 * coercing the arg to a string. A non-empty unit returns a CSS string
 * (`"16rem"`).
 *
 * @param {number|null|undefined} value - The numeric part. A nullish or
 *   non-finite value returns `null` (an empty / cleared field).
 * @param {string} [unit] - The unit token (`"px"`, `"rem"`, `"%"`, ...), or
 *   empty / omitted for a unitless number.
 * @returns {number|string|null} A `Number` when `unit` is empty, a CSS string
 *   when a unit is given, or `null` when there's no numeric value.
 */
export function formatDimension(value, unit = "") {
  if (value == null || !Number.isFinite(value)) {
    return null;
  }
  return unit ? `${value}${unit}` : value;
}
