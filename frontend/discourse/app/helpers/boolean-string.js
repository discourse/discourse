/**
 * Converts a boolean value to its string representation ("true" or "false").
 * When omitFalse is true (default), falsy values return undefined instead of "false".
 *
 * @param {boolean} value - The boolean value to convert
 * @param {Object} [opts={ omitFalse: true }] - Options object
 * @param {boolean} [opts.omitFalse=true] - When true, falsy values return undefined instead of "false"
 * @returns {string|undefined} Returns "true" for truthy values, "false" for falsy values (unless omitted)
 *
 * @example
 * // Returns "true"
 * booleanString(true);
 *
 * @example
 * // Returns undefined (with default options)
 * booleanString(false);
 *
 * @example
 * // Returns "false"
 * booleanString(false, { omitFalse: false });
 */
export default function booleanString(value, opts = { omitFalse: true }) {
  if (opts.omitFalse && !value) {
    return;
  }

  return value ? "true" : "false";
}
