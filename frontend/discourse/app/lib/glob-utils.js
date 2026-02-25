// @ts-check
import picomatch from "picomatch";

/**
 * Validates that a glob pattern can be compiled by picomatch.
 *
 * Instead of using a restrictive regex, this function attempts to compile
 * the pattern with picomatch using strict mode. This allows full picomatch
 * syntax including advanced features like brace expansion, character classes,
 * and negation, while catching syntax errors like unbalanced brackets.
 *
 * @param {string} pattern - The pattern to validate.
 * @returns {boolean} True if the pattern is valid picomatch syntax.
 *
 * @example
 * isValidGlobPattern("sidebar-*");         // true
 * isValidGlobPattern("{a,b}-blocks");      // true
 * isValidGlobPattern("[unclosed");         // false (unbalanced bracket)
 */
export function isValidGlobPattern(pattern) {
  try {
    // Compile with strictBrackets to throw on imbalanced brackets/braces/parens.
    // Without this option, picomatch treats malformed patterns as literals.
    picomatch(pattern, { strictBrackets: true });
    return true;
  } catch {
    return false;
  }
}
