import picomatch from "picomatch";
import { withoutPrefix } from "discourse/lib/get-url";
import { findClosestMatch } from "discourse/lib/string-similarity";

/**
 * Valid shortcut patterns for semantic URL matching.
 *
 * Shortcuts provide semantic URL matching based on page context rather than
 * explicit URL patterns. They are identified by a leading `$` character
 * (e.g., `$CATEGORY_PAGES`).
 *
 * @constant {ReadonlyArray<string>}
 */
export const VALID_SHORTCUTS = Object.freeze([
  "$CATEGORY_PAGES",
  "$DISCOVERY_PAGES",
  "$HOMEPAGE",
  "$TAG_PAGES",
  "$TOP_MENU",
]);

/**
 * Checks if a pattern is a shortcut (starts with `$`).
 *
 * Shortcuts are special semantic identifiers that match based on page context
 * rather than URL patterns. They are prefixed with `$` and use UPPER_CASE names.
 *
 * @param {string} pattern - The pattern string to check.
 * @returns {boolean} True if the pattern is a shortcut (starts with `$`).
 *
 * @example
 * isShortcut("$CATEGORY_PAGES"); // true
 * isShortcut("/c/**");           // false
 */
export function isShortcut(pattern) {
  return typeof pattern === "string" && pattern.startsWith("$");
}

/**
 * Checks if a URL pattern looks like it might be a shortcut typo.
 *
 * This function detects patterns like "CATEGORIES", "CATEGORY_PAGES", or
 * "homepage" that look like they were meant to be shortcuts but are missing
 * the `$` prefix. It uses fuzzy matching against the shortcut names.
 *
 * @param {string} pattern - The URL pattern to check.
 * @returns {string|null} The likely intended shortcut (with `$`), or null.
 *
 * @example
 * looksLikeShortcutTypo("CATEGORY_PAGES"); // "$CATEGORY_PAGES"
 * looksLikeShortcutTypo("CATEGORIES");     // "$CATEGORY_PAGES"
 * looksLikeShortcutTypo("homepage");       // "$HOMEPAGE"
 * looksLikeShortcutTypo("/c/**");          // null
 */
export function looksLikeShortcutTypo(pattern) {
  if (typeof pattern !== "string" || isShortcut(pattern)) {
    return null;
  }

  // Skip patterns that look like actual URL paths
  if (
    pattern.startsWith("/") ||
    pattern.includes("*") ||
    pattern.includes("?")
  ) {
    return null;
  }

  // Only consider patterns that look like shortcut attempts:
  // - All uppercase (HOMEPAGE, CATEGORY_PAGES)
  // - Has underscores (category_pages)
  // - Matches shortcut word patterns (e.g., "categories" matches "category")
  const upperPattern = pattern.toUpperCase();
  const looksLikeShortcut =
    pattern === upperPattern || // All uppercase
    pattern.includes("_") || // Has underscores
    /^[A-Za-z]+$/.test(pattern); // Single word (might be abbreviated shortcut)

  if (!looksLikeShortcut) {
    return null;
  }

  // Check if pattern matches a shortcut name (Jaro-Winkler handles prefixes naturally)
  const normalizedPattern = `$${upperPattern}`;
  return findClosestMatch(normalizedPattern, VALID_SHORTCUTS);
}

/**
 * Normalizes a URL path for matching.
 *
 * This function prepares a URL for glob pattern matching by:
 * 1. Stripping the Discourse subfolder prefix (if Discourse runs on `/forum`, etc.)
 * 2. Removing query strings and hash fragments
 * 3. Removing trailing slashes (except for root `/`)
 *
 * This ensures theme authors don't need to know about subfolder configurations
 * and can write patterns like `/c/**` that work universally.
 *
 * @param {string} url - The URL to normalize (typically `router.currentURL`).
 * @returns {string} The normalized path, ready for pattern matching.
 *
 * @example
 * // Subfolder stripping
 * normalizePath("/forum/c/general");     // "/c/general"
 *
 * // Query string removal
 * normalizePath("/c/general?foo=bar");   // "/c/general"
 *
 * // Hash fragment removal
 * normalizePath("/c/general#section");   // "/c/general"
 *
 * // Trailing slash removal
 * normalizePath("/c/general/");          // "/c/general"
 *
 * // Root path preserved
 * normalizePath("/");                    // "/"
 *
 * // Empty/null handling
 * normalizePath("");                     // "/"
 * normalizePath(null);                   // "/"
 */
export function normalizePath(url) {
  if (!url) {
    return "/";
  }

  // Strip subfolder prefix first (e.g., /forum -> "")
  let path = withoutPrefix(url);

  // Strip query string and hash fragment
  path = path.split("?")[0].split("#")[0];

  // Remove trailing slash (except for root)
  if (path.length > 1 && path.endsWith("/")) {
    path = path.slice(0, -1);
  }

  return path || "/";
}

/**
 * Validates that a URL pattern can be compiled by picomatch.
 *
 * Uses strictBrackets to throw on imbalanced brackets/braces/parens.
 * Without this option, picomatch treats malformed patterns as literals.
 *
 * @param {string} pattern - The pattern to validate.
 * @returns {boolean} True if the pattern is valid picomatch syntax.
 *
 * @example
 * isValidUrlPattern("/c/**");       // true
 * isValidUrlPattern("/{a,b}");      // true
 * isValidUrlPattern("[unclosed");   // false
 */
export function isValidUrlPattern(pattern) {
  try {
    picomatch(pattern, { strictBrackets: true });
    return true;
  } catch {
    return false;
  }
}

/**
 * Matches a URL path against a glob pattern using picomatch.
 *
 * Supports full picomatch glob syntax:
 * - `*` matches a single path segment (no slashes)
 * - `**` matches zero or more path segments
 * - `?` matches a single character
 * - `[abc]` matches any character in the brackets
 * - `{a,b}` matches any of the comma-separated patterns
 *
 * @param {string} path - The normalized URL path to test.
 * @param {string} pattern - The glob pattern to match against.
 * @returns {boolean} True if the path matches the pattern.
 *
 * @example
 * // Single wildcard
 * matchUrlPattern("/c/general", "/c/*");      // true
 * matchUrlPattern("/c/general/sub", "/c/*");  // false
 *
 * @example
 * // Double wildcard
 * matchUrlPattern("/c/general/sub", "/c/**"); // true
 *
 * @example
 * // Brace expansion
 * matchUrlPattern("/latest", "/{latest,top}"); // true
 */
export function matchUrlPattern(path, pattern) {
  const isMatch = picomatch(pattern, { dot: true });
  return isMatch(path);
}

/**
 * Checks if any URL pattern in the array matches the given path.
 *
 * Shortcut patterns (starting with `$`) are filtered out and should be
 * handled separately by the route condition's shortcut matching logic.
 *
 * @param {string} path - The normalized URL path to test.
 * @param {string[]} patterns - Array of patterns, which may include shortcuts.
 * @returns {boolean} True if any non-shortcut pattern matches the path.
 *
 * @example
 * matchesAnyPattern("/c/general", ["/c/**", "$CATEGORY_PAGES"]); // true (matches /c/**)
 * matchesAnyPattern("/latest", ["/c/**", "$CATEGORY_PAGES"]);    // false
 */
export function matchesAnyPattern(path, patterns) {
  return patterns
    .filter((p) => !isShortcut(p))
    .some((pattern) => matchUrlPattern(path, pattern));
}
