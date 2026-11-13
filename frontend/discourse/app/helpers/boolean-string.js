import deprecate from "discourse/lib/deprecated";

/**
 * Converts a boolean value to its string representation ("true" or "false").
 * When omitFalse is true (default), falsy values return undefined instead of "false".
 *
 * @param {boolean | undefined} value - The boolean value to convert; `undefined` counts as false
 * @param {Object} [opts={ omitFalse: true }] - Options object
 * @param {boolean} [opts.omitFalse=true] - When true, falsy values return undefined instead of "false"
 * @returns {string|undefined} Returns "true" for truthy values, "false" for falsy values (unless omitted)
 * @deprecated Use inline `if value "true" "false"` or `if value "true"` instead.
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
  deprecate(
    'The booleanString helper is deprecated. Use {{if value "true" "false"}} to include false, or {{if value "true"}} to omit it.',
    {
      id: "discourse.boolean-string-helper",
      since: "2026.10.0",
    }
  );

  if (opts.omitFalse && !value) {
    return;
  }

  return value ? "true" : "false";
}
