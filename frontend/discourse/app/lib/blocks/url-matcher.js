import picomatch from "picomatch";
import { withoutPrefix } from "discourse/lib/get-url";

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
 * @param {string} path - The normalized URL path to test.
 * @param {string[]} patterns - Array of URL patterns.
 * @returns {boolean} True if any pattern matches the path.
 *
 * @example
 * matchesAnyPattern("/c/general", ["/c/**", "/t/**"]); // true (matches /c/**)
 * matchesAnyPattern("/latest", ["/c/**", "/t/**"]);    // false
 */
export function matchesAnyPattern(path, patterns) {
  return patterns.some((pattern) => matchUrlPattern(path, pattern));
}
