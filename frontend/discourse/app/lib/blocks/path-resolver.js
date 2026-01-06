/**
 * Retrieves a value from a nested object using dot-notation path.
 *
 * This utility safely navigates through nested object properties using a
 * dot-separated path string. It handles null/undefined values gracefully
 * at any level of the path.
 *
 * @param {Object} obj - The object to get the value from.
 * @param {string} path - Dot-notation path (e.g., "user.trust_level").
 * @returns {*} The value at the path, or undefined if not found or if any
 *              intermediate value is null/undefined.
 *
 * @example
 * const user = { profile: { name: "Alice", settings: { theme: "dark" } } };
 * getByPath(user, "profile.name"); // "Alice"
 * getByPath(user, "profile.settings.theme"); // "dark"
 * getByPath(user, "profile.missing"); // undefined
 * getByPath(user, "profile.settings.missing.deep"); // undefined (safe)
 */
export function getByPath(obj, path) {
  if (!obj || !path) {
    return undefined;
  }

  const parts = path.split(".");
  let current = obj;

  for (const part of parts) {
    if (current === null || current === undefined) {
      return undefined;
    }
    current = current[part];
  }

  return current;
}
