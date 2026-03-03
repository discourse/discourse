import dasherize from "discourse/helpers/dasherize";

/**
 * Converts a string to a valid CSS identifier (class name, ID, etc.).
 * Replaces colons and dots with hyphens and converts camelCase to kebab-case.
 *
 * @param {string} name - The string to convert.
 * @returns {string} A CSS-safe kebab-case identifier.
 */
export default function cssIdentifier(name = "") {
  return dasherize(name.replace(/:/g, "-"));
}
