import picomatch from "picomatch";
import { raiseBlockError } from "discourse/lib/blocks/error";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";

/**
 * Checks if a pattern targets a namespaced outlet.
 *
 * Namespaced outlets use a colon separator to identify outlets defined by
 * plugins or themes (e.g., `plugin-name:outlet-name`, `theme-name:outlet-name`).
 * These patterns bypass known-outlet validation since they reference outlets
 * that may not be in the core `BLOCK_OUTLETS` registry.
 *
 * @param {string} pattern - The pattern to check.
 * @returns {boolean} True if the pattern contains a namespace separator.
 *
 * @example
 * isNamespacedPattern("my-plugin:dashboard");      // true
 * isNamespacedPattern("my-theme:hero-section");    // true
 * isNamespacedPattern("sidebar-blocks");           // false
 * isNamespacedPattern("sidebar-*");                // false
 */
export function isNamespacedPattern(pattern) {
  return pattern.includes(":");
}

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
function isValidGlobPattern(pattern) {
  try {
    // Compile with strictBrackets to throw on imbalanced brackets/braces/parens.
    // Without this option, picomatch treats malformed patterns as literals.
    picomatch(pattern, { strictBrackets: true });
    return true;
  } catch {
    return false;
  }
}

/**
 * Matches an outlet name against a glob pattern using picomatch.
 *
 * Outlet names follow kebab-case (lowercase letters, numbers, hyphens).
 * Supported glob syntax:
 * - `*` matches any characters
 * - `?` matches a single character
 * - `[abc]` matches any character in the brackets
 * - `{a,b}` matches any of the comma-separated patterns
 * - `!(pattern)` negative match (matches anything except pattern)
 *
 * @param {string} outlet - The outlet name to test.
 * @param {string} pattern - The glob pattern to match against.
 * @returns {boolean} True if the outlet matches the pattern.
 *
 * @example
 * // Exact match
 * matchOutletPattern("sidebar-blocks", "sidebar-blocks");   // true
 *
 * @example
 * // Wildcard matching
 * matchOutletPattern("sidebar-left", "sidebar-*");          // true
 * matchOutletPattern("sidebar-left-top", "sidebar-*");      // true
 *
 * @example
 * // Brace expansion
 * matchOutletPattern("sidebar-blocks", "{sidebar,footer}-*"); // true
 *
 * @example
 * // Character class
 * matchOutletPattern("modal-1", "modal-[0-9]");             // true
 *
 * @example
 * // Negation
 * matchOutletPattern("sidebar-blocks", "!(*-debug)");       // true
 */
export function matchOutletPattern(outlet, pattern) {
  // Use dot: true to match dots in outlet names (e.g., namespaced outlets)
  const isMatch = picomatch(pattern, { dot: true });
  return isMatch(outlet);
}

/**
 * Validates that outlet patterns are a valid array of strings with valid picomatch syntax.
 *
 * This function is called at decoration time to catch configuration errors early.
 * It validates:
 * 1. The patterns parameter is an array (or null/undefined for no restrictions)
 * 2. Each pattern in the array is a string
 * 3. Each pattern can be compiled by picomatch
 *
 * @param {*} patterns - The patterns to validate.
 * @param {string} blockName - Block name for error messages.
 * @param {string} propertyName - Property name ("allowedOutlets" or "deniedOutlets").
 *
 * @example
 * validateOutletPatterns(["sidebar-*", "homepage-blocks"], "my-block", "allowedOutlets");
 * validateOutletPatterns(null, "my-block", "allowedOutlets"); // null means no restrictions
 */
export function validateOutletPatterns(patterns, blockName, propertyName) {
  // null/undefined means "no restrictions" - this is valid
  if (patterns == null) {
    return;
  }

  // Must be an array
  if (!Array.isArray(patterns)) {
    raiseBlockError(
      `Block "${blockName}": ${propertyName} must be an array of strings, got ${typeof patterns}.`
    );
    return;
  }

  // Validate each pattern in the array
  for (let i = 0; i < patterns.length; i++) {
    const pattern = patterns[i];

    // Each pattern must be a string
    if (typeof pattern !== "string") {
      raiseBlockError(
        `Block "${blockName}": ${propertyName}[${i}] must be a string, got ${typeof pattern}.`
      );
      continue;
    }

    // Each pattern must be valid picomatch syntax
    if (!isValidGlobPattern(pattern)) {
      raiseBlockError(
        `Block "${blockName}": ${propertyName}[${i}] "${pattern}" is not valid glob syntax.`
      );
    }
  }
}

/**
 * Detects if allowed and denied patterns could match the same outlet name.
 *
 * This function uses two strategies to detect conflicts:
 *
 * 1. **Known outlets check**: Tests each outlet in `BLOCK_OUTLETS` against both
 *    pattern lists. This catches conflicts for outlets that actually exist.
 *
 * 2. **Synthetic test strings**: Generates test strings by replacing wildcards
 *    in patterns with concrete characters. This catches conflicts for outlets
 *    that don't exist yet (e.g., plugin-defined outlets).
 *
 * @param {string[]|null} allowedPatterns - Patterns for allowed outlets.
 * @param {string[]|null} deniedPatterns - Patterns for denied outlets.
 * @returns {{ conflict: boolean, details?: { outlet: string, allowed: string, denied: string } }}
 *   Returns conflict: true with details if a conflict is detected.
 *
 * @example
 * // No conflict
 * detectPatternConflicts(["sidebar-*"], ["homepage-*"]);
 * // { conflict: false }
 *
 * @example
 * // Conflict detected
 * detectPatternConflicts(["*-blocks"], ["sidebar-*"]);
 * // { conflict: true, details: { outlet: "sidebar-blocks", allowed: "*-blocks", denied: "sidebar-*" } }
 */
export function detectPatternConflicts(allowedPatterns, deniedPatterns) {
  // Early exit: No conflict possible if either list is empty/null
  if (!allowedPatterns?.length || !deniedPatterns?.length) {
    return { conflict: false };
  }

  // Strategy 1: Check against known outlets (catches most practical conflicts)
  // This is fast and catches conflicts for outlets that actually exist.
  for (const outlet of BLOCK_OUTLETS) {
    const allowedMatch = allowedPatterns.find((p) =>
      matchOutletPattern(outlet, p)
    );
    const deniedMatch = deniedPatterns.find((p) =>
      matchOutletPattern(outlet, p)
    );
    if (allowedMatch && deniedMatch) {
      return {
        conflict: true,
        details: { outlet, allowed: allowedMatch, denied: deniedMatch },
      };
    }
  }

  // Strategy 2: Generate synthetic test strings from patterns
  // This catches conflicts for outlets that don't exist yet (e.g., plugin outlets).
  // We derive test strings by replacing glob wildcards with concrete characters.
  const testStrings = new Set();
  [...allowedPatterns, ...deniedPatterns].forEach((pattern) => {
    // Replace all glob special chars with 'x' to get a literal string
    // e.g., "sidebar-*" -> "sidebar-x"
    const literal = pattern.replace(/[*?[\]{}!()]/g, "x");
    testStrings.add(literal);

    // Replace single wildcards with a test word
    // e.g., "sidebar-*" -> "sidebar-test"
    testStrings.add(pattern.replace(/\*/g, "test"));

    // Replace double wildcards with a hyphenated string
    // e.g., "admin-**" -> "admin-a-b-c"
    testStrings.add(pattern.replace(/\*\*/g, "a-b-c"));
  });

  // Test each synthetic string against both pattern lists
  for (const test of testStrings) {
    const allowedMatch = allowedPatterns.find((p) =>
      matchOutletPattern(test, p)
    );
    const deniedMatch = deniedPatterns.find((p) => matchOutletPattern(test, p));
    if (allowedMatch && deniedMatch) {
      return {
        conflict: true,
        details: { outlet: test, allowed: allowedMatch, denied: deniedMatch },
      };
    }
  }

  return { conflict: false };
}

/**
 * Checks if a block is permitted to render in a specific outlet.
 *
 * The permission check follows these rules:
 * 1. If `deniedPatterns` is specified and the outlet matches any pattern, deny.
 * 2. If `allowedPatterns` is specified and the outlet doesn't match any pattern, deny.
 * 3. Otherwise, permit.
 *
 * Denial takes precedence over allowance. An empty `allowedOutlets` array means
 * "no outlets allowed" (strict whitelist).
 *
 * @param {string} outlet - The outlet name to check.
 * @param {string[]|null} allowedPatterns - Patterns for allowed outlets.
 * @param {string[]|null} deniedPatterns - Patterns for denied outlets.
 * @returns {{ permitted: boolean, reason?: string }}
 *   Returns permitted: true if allowed, or permitted: false with a reason if denied.
 *
 * @example
 * // No restrictions
 * isBlockPermittedInOutlet("sidebar-blocks", null, null);
 * // { permitted: true }
 *
 * @example
 * // Allowed by pattern
 * isBlockPermittedInOutlet("sidebar-blocks", ["sidebar-*"], null);
 * // { permitted: true }
 *
 * @example
 * // Denied by pattern
 * isBlockPermittedInOutlet("sidebar-blocks", null, ["sidebar-*"]);
 * // { permitted: false, reason: 'outlet "sidebar-blocks" matches deniedOutlets pattern "sidebar-*"' }
 *
 * @example
 * // Not in allowed list
 * isBlockPermittedInOutlet("homepage-blocks", ["sidebar-*"], null);
 * // { permitted: false, reason: 'outlet "homepage-blocks" does not match any allowedOutlets pattern' }
 */
export function isBlockPermittedInOutlet(
  outlet,
  allowedPatterns,
  deniedPatterns
) {
  // Check denied list first (explicit deny always wins)
  // This ensures that even if a pattern appears in both lists (shouldn't happen
  // due to conflict detection), denial takes precedence for safety.
  if (deniedPatterns?.length > 0) {
    const deniedMatch = deniedPatterns.find((p) =>
      matchOutletPattern(outlet, p)
    );
    if (deniedMatch) {
      return {
        permitted: false,
        reason: `outlet "${outlet}" matches deniedOutlets pattern "${deniedMatch}"`,
      };
    }
  }

  // If allowed list is specified, outlet must match at least one pattern.
  // An empty allowedOutlets array means "no outlets allowed" (strict whitelist).
  if (allowedPatterns !== null && allowedPatterns !== undefined) {
    // Empty array = strict whitelist with no allowed outlets
    if (allowedPatterns.length === 0) {
      return {
        permitted: false,
        reason: `outlet "${outlet}" does not match any allowedOutlets pattern (allowedOutlets is empty)`,
      };
    }

    const allowedMatch = allowedPatterns.find((p) =>
      matchOutletPattern(outlet, p)
    );
    if (!allowedMatch) {
      return {
        permitted: false,
        reason: `outlet "${outlet}" does not match any allowedOutlets pattern`,
      };
    }
  }

  // No restrictions, or passed all checks
  return { permitted: true };
}

/**
 * Warns if patterns don't match any known outlet (helps catch typos).
 *
 * This function is called at decoration time to help developers catch
 * configuration mistakes. It skips namespaced patterns since they target
 * plugin/theme outlets that aren't in the core `BLOCK_OUTLETS` registry.
 *
 * @param {string[]|null} patterns - The patterns to check.
 * @param {string} blockName - Block name for warning messages.
 * @param {string} propertyName - Property name ("allowedOutlets" or "deniedOutlets").
 *
 * @example
 * // Warns about typo
 * warnUnknownOutletPatterns(["sidbar-*"], "my-block", "allowedOutlets");
 * // Console: [Blocks] Block "my-block": allowedOutlets pattern "sidbar-*" does not match any known outlet...
 *
 * @example
 * // No warning for namespaced patterns
 * warnUnknownOutletPatterns(["my-plugin:custom-outlet"], "my-block", "allowedOutlets");
 * // No warning (namespaced patterns are skipped)
 */
export function warnUnknownOutletPatterns(patterns, blockName, propertyName) {
  if (!patterns?.length) {
    return;
  }

  for (const pattern of patterns) {
    // Skip namespaced patterns - they reference plugin/theme outlets
    // that aren't in BLOCK_OUTLETS
    if (isNamespacedPattern(pattern)) {
      continue;
    }

    // Check if pattern matches at least one known outlet
    const matchesKnown = BLOCK_OUTLETS.some((outlet) =>
      matchOutletPattern(outlet, pattern)
    );

    if (!matchesKnown) {
      // eslint-disable-next-line no-console
      console.warn(
        `[Blocks] Block "${blockName}": ${propertyName} pattern "${pattern}" ` +
          `does not match any known outlet. This may be a typo. ` +
          `Known outlets: ${BLOCK_OUTLETS.join(", ")}`
      );
    }
  }
}
