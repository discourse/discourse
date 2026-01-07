import { findClosestMatch } from "discourse/lib/string-similarity";

/**
 * Evaluates a value matcher spec against an actual value.
 * Supports the same AND/OR/NOT logic as condition evaluation.
 *
 * Supports:
 * - Exact match: `123`, `"foo"`
 * - Array of values (OR): `[123, 456]` matches if actual is any of these
 * - RegExp: `/^foo/` matches if actual matches the pattern
 * - NOT: `{ not: value }` matches if actual does NOT match value
 * - ANY (OR): `{ any: [...] }` matches if actual matches any spec in array
 *
 * @param {Object} options - Options object.
 * @param {*} options.actual - The actual value to test.
 * @param {*} options.expected - The expected value spec (exact, array, regex, or AND/OR/NOT spec).
 * @param {string} [options.paramName] - Name of param being matched (for debug output).
 * @returns {boolean} True if the actual value matches the expected spec.
 */
export function matchValue({ actual, expected, paramName = "" }) {
  // Handle arrays first (before checking for `any`/`not` properties)
  // because Ember prototype extensions add `any()` method to arrays
  if (Array.isArray(expected)) {
    if (expected.length > 0 && !isSimpleValueArray(expected)) {
      // AND logic: Array of non-primitive conditions, all must pass
      return expected.every((exp) =>
        matchValue({ actual, expected: exp, paramName })
      );
    }
    // Simple array of values (OR - match any)
    return matchSimpleValue(actual, expected);
  }

  // OR logic: { any: [...] }
  if (expected?.any !== undefined) {
    return expected.any.some((exp) =>
      matchValue({ actual, expected: exp, paramName })
    );
  }

  // NOT logic: { not: ... }
  if (expected?.not !== undefined) {
    return !matchValue({ actual, expected: expected.not, paramName });
  }

  // Simple value matching (leaf node)
  return matchSimpleValue(actual, expected);
}

/**
 * Checks if an array is a simple value array (for OR matching) vs a condition
 * array (for AND matching). Simple value arrays contain only primitives (strings,
 * numbers, booleans, null) or RegExp objects.
 *
 * @param {Array} arr - The array to check.
 * @returns {boolean} True if all items are primitives or RegExp.
 */
function isSimpleValueArray(arr) {
  return arr.every(
    (item) =>
      typeof item !== "object" || item === null || item instanceof RegExp
  );
}

/**
 * Matches a simple value (exact, array of primitives, or regex).
 *
 * Note: When `expected` is a RegExp, `actual` is converted to a string before
 * testing. This means numeric values like `123` will match patterns like `/1/`
 * (because 123 is converted to "123").
 *
 * @param {*} actual - The actual value.
 * @param {*} expected - The expected value (primitive, array of primitives, or RegExp).
 * @returns {boolean} True if matches.
 */
function matchSimpleValue(actual, expected) {
  // RegExp pattern - coerce actual to string for testing
  if (expected instanceof RegExp) {
    return expected.test(String(actual));
  }

  // Array of values (OR - match any)
  if (Array.isArray(expected)) {
    return expected.some((exp) => matchSimpleValue(actual, exp));
  }

  // Exact match (strict equality)
  return actual === expected;
}

/**
 * Checks if a failed match is due to a string/number type mismatch.
 * Used to provide helpful debug hints.
 *
 * @param {*} actual - The actual value.
 * @param {*} expected - The expected value.
 * @returns {boolean} True if the values would match with type coercion.
 */
export function isTypeMismatch(actual, expected) {
  // Already matches - not a mismatch
  if (actual === expected) {
    return false;
  }

  // Check if string/number coercion would make them equal
  if (
    (typeof actual === "string" && typeof expected === "number") ||
    (typeof actual === "number" && typeof expected === "string")
  ) {
    return String(actual) === String(expected);
  }

  // Check arrays for type mismatches
  if (Array.isArray(expected)) {
    return expected.some((exp) => isTypeMismatch(actual, exp));
  }

  // Check { any: [...] } for type mismatches
  if (expected?.any !== undefined) {
    return expected.any.some((exp) => isTypeMismatch(actual, exp));
  }

  return false;
}

/**
 * Evaluates params/queryParams object matching with full AND/OR/NOT support.
 *
 * Supports:
 * - Object with keys: AND logic (all keys must match)
 * - Array of objects: AND logic (all must match)
 * - `{ any: [...] }`: OR logic (any must match)
 * - `{ not: {...} }`: NOT logic (must NOT match)
 *
 * Keys starting with backslash are escaped (e.g., `"\\any"` matches literal param `"any"`).
 *
 * @param {Object} options - Options object.
 * @param {Object} options.actualParams - Current params from router.
 * @param {Object|Array} options.expectedParams - Expected params spec.
 * @param {Object} [options.context] - Debug context.
 * @param {boolean} [options.context.debug] - Enable debug logging.
 * @param {number} [options.context._depth] - Nesting depth for logging.
 * @param {Object} [options.context.logger] - Logger interface from dev-tools (optional).
 * @param {string} [options.label] - Label for debug output (e.g., "params", "queryParams").
 * @returns {boolean} True if params match.
 */
export function matchParams({
  actualParams,
  expectedParams,
  context = {},
  label = "params",
}) {
  const isLoggingEnabled = context.debug ?? false;
  const depth = context._depth ?? 0;
  const logger = context.logger;

  if (!expectedParams) {
    return true; // No expected params, always pass
  }

  // Array of param specs = AND logic (all must match)
  if (Array.isArray(expectedParams)) {
    // Log combinator BEFORE children so it appears first in tree
    logger?.logCondition?.({
      type: "AND",
      args: `${expectedParams.length} ${label} specs`,
      result: null,
      depth,
    });

    const results = expectedParams.map((spec, i) =>
      matchParams({
        actualParams,
        expectedParams: spec,
        context: { debug: isLoggingEnabled, _depth: depth + 1, logger },
        label: `${label}[${i}]`,
      })
    );
    const allPassed = results.every(Boolean);

    // Update combinator result after children evaluated
    logger?.updateCombinatorResult?.(allPassed, depth);
    return allPassed;
  }

  // OR logic: { any: [...] }
  if (expectedParams.any !== undefined) {
    const specs = expectedParams.any;

    // Log combinator BEFORE children so it appears first in tree
    logger?.logCondition?.({
      type: "OR",
      args: `${specs.length} ${label} specs`,
      result: null,
      depth,
    });

    const results = specs.map((spec, i) =>
      matchParams({
        actualParams,
        expectedParams: spec,
        context: { debug: isLoggingEnabled, _depth: depth + 1, logger },
        label: `${label}[${i}]`,
      })
    );
    const anyPassed = results.some(Boolean);

    // Update combinator result after children evaluated
    logger?.updateCombinatorResult?.(anyPassed, depth);
    return anyPassed;
  }

  // NOT logic: { not: {...} }
  if (expectedParams.not !== undefined) {
    // Log combinator BEFORE children so it appears first in tree
    logger?.logCondition?.({
      type: "NOT",
      args: null,
      result: null,
      depth,
    });

    const innerResult = matchParams({
      actualParams,
      expectedParams: expectedParams.not,
      context: { debug: isLoggingEnabled, _depth: depth + 1, logger },
      label,
    });
    const result = !innerResult;

    // Update combinator result after children evaluated
    logger?.updateCombinatorResult?.(result, depth);
    return result;
  }

  // Plain object with keys = AND logic across all keys
  // Note: keys starting with \ are escaped (e.g., "\\any" matches literal param "any")
  const keys = Object.keys(expectedParams);
  if (keys.length === 0) {
    return true;
  }

  // Collect match results for debug logging
  const matches = [];

  for (const key of keys) {
    // Strip leading backslash for escaped keys (e.g., "\\any" -> "any")
    const actualKey = key.startsWith("\\") ? key.slice(1) : key;
    const expected = expectedParams[key];
    const actual = actualParams?.[actualKey];
    const result = matchValue({ actual, expected, paramName: actualKey });
    matches.push({ key: actualKey, expected, actual, result });
  }

  const allPassed = matches.every((m) => m.result);

  // Log as a nested group with all param matches
  logger?.logParamGroup?.({
    label,
    matches,
    result: allPassed,
    depth,
  });

  return allPassed;
}

/**
 * Valid operator keys for param/queryParam specs.
 * These are the only keys with special meaning in param matching.
 */
const VALID_OPERATOR_KEYS = Object.freeze(["any", "not"]);

/**
 * Validates a param spec for typos in operator keys.
 *
 * Recursively checks that any object key that looks like an operator typo
 * (e.g., "an" instead of "any", "nto" instead of "not") is flagged.
 *
 * @param {*} spec - The param spec to validate.
 * @param {string} path - Current path for error messages.
 * @param {Function} raiseError - Function to call with error message.
 */
export function validateParamSpec(spec, path, raiseError) {
  if (spec === null || spec === undefined) {
    return;
  }

  // Skip primitives and RegExp - they're just values
  if (typeof spec !== "object" || spec instanceof RegExp) {
    return;
  }

  // Arrays: validate each item
  if (Array.isArray(spec)) {
    spec.forEach((item, i) => {
      validateParamSpec(item, `${path}[${i}]`, raiseError);
    });
    return;
  }

  // Objects: check keys for operator typos
  const keys = Object.keys(spec);

  for (const key of keys) {
    // Check if this key looks like a typo of a valid operator
    // Skip if it's a valid operator or an escaped key (starts with \)
    if (!VALID_OPERATOR_KEYS.includes(key) && !key.startsWith("\\")) {
      // Use Jaro-Winkler to check if it's similar to an operator
      const suggestion = findClosestMatch(key, VALID_OPERATOR_KEYS, {
        minSimilarity: 0.7,
      });

      if (suggestion) {
        raiseError(
          `Unknown key "${key}" at ${path}. Did you mean "${suggestion}"?`
        );
      }
    }

    // Recursively validate the value
    validateParamSpec(spec[key], `${path}.${key}`, raiseError);
  }
}
