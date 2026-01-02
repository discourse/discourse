/**
 * Shared value formatting utilities for dev tools.
 *
 * Provides consistent value display across block-debug and plugin-outlet-debug
 * components, ensuring uniform representation of different data types.
 *
 * @module dev-tools/lib/value-formatter
 */

/**
 * Maximum length for string values before truncation.
 * Strings longer than this will be truncated with "..." appended.
 *
 * @constant {number}
 */
const MAX_STRING_LENGTH = 50;

/**
 * Formats a value for display in debug tables. Each type is handled differently
 * to provide a concise yet informative representation that fits in the UI.
 *
 * @param {any} value - The value to format.
 * @param {Object} [options] - Formatting options.
 * @param {boolean} [options.expandArrays=false] - If true, shows array contents
 *   instead of just "Array(n)". Useful for condition trees where values matter.
 * @param {boolean} [options.handleSymbols=false] - If true, formats Symbols with
 *   their description. Useful for condition trees using Symbol route shortcuts.
 * @param {boolean} [options.handleRegExp=false] - If true, formats RegExp instances
 *   as their string pattern. Useful for condition trees with regex routes.
 * @returns {string} A human-readable string representation of the value.
 *
 * @example
 * formatValue(null);                    // "null"
 * formatValue("hello world");           // '"hello world"'
 * formatValue([1, 2, 3]);               // "Array(3)"
 * formatValue([1, 2], { expandArrays: true }); // "[1, 2]"
 * formatValue(Symbol("test"), { handleSymbols: true }); // "Symbol(test)"
 */
export function formatValue(value, options = {}) {
  const {
    expandArrays = false,
    handleSymbols = false,
    handleRegExp = false,
  } = options;

  // Null and undefined are displayed as literal keywords
  if (value === null) {
    return "null";
  }
  if (value === undefined) {
    return "undefined";
  }

  // Symbols show their description (optional - for condition trees)
  if (handleSymbols && typeof value === "symbol") {
    return `Symbol(${value.description || ""})`;
  }

  // Strings are quoted and truncated to prevent UI overflow
  if (typeof value === "string") {
    const truncated =
      value.length > MAX_STRING_LENGTH
        ? value.slice(0, MAX_STRING_LENGTH) + "..."
        : value;
    return `"${truncated}"`;
  }

  // Numbers and booleans can be displayed directly as their string representation
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }

  // Arrays: either show contents or just length depending on context
  if (Array.isArray(value)) {
    if (expandArrays) {
      return `[${value.map((v) => formatValue(v, options)).join(", ")}]`;
    }
    return `Array(${value.length})`;
  }

  // RegExp instances show their pattern (optional - for condition trees)
  if (handleRegExp && value instanceof RegExp) {
    return value.toString();
  }

  // Functions show their name to help identify callbacks
  if (typeof value === "function") {
    return `fn ${value.name || "anonymous"}()`;
  }

  // Objects show their constructor name (e.g., "User {...}") or just "{...}"
  if (typeof value === "object") {
    const name = value.constructor?.name;
    if (name && name !== "Object") {
      return `${name} {...}`;
    }
    return "{...}";
  }

  // Fallback for any other types (bigints, etc.)
  return String(value);
}

/**
 * Determines the type label to display for a value. This provides a quick
 * visual indicator of what kind of data is in each argument.
 *
 * @param {any} value - The value to get the type info for.
 * @returns {string} A type label (e.g., "string", "number", "array", "object").
 *
 * @example
 * getTypeInfo(null);        // "null"
 * getTypeInfo([1, 2, 3]);   // "array"
 * getTypeInfo({ foo: 1 });  // "object"
 * getTypeInfo("hello");     // "string"
 */
export function getTypeInfo(value) {
  if (value === null) {
    return "null";
  }
  if (value === undefined) {
    return "undefined";
  }
  // Arrays are identified separately since typeof returns "object" for arrays
  if (Array.isArray(value)) {
    return "array";
  }
  return typeof value;
}
