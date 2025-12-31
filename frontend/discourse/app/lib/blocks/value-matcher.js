import { blockDebugLogger } from "./debug-logger";

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
 * @param {*} actual - The actual value.
 * @param {*} expected - The expected value (primitive, array of primitives, or RegExp).
 * @returns {boolean} True if matches.
 */
function matchSimpleValue(actual, expected) {
  // RegExp pattern
  if (expected instanceof RegExp) {
    return expected.test(String(actual));
  }

  // Array of values (OR - match any)
  if (Array.isArray(expected)) {
    return expected.some((exp) => matchSimpleValue(actual, exp));
  }

  // Exact match
  return actual === expected;
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

  if (!expectedParams) {
    return true; // No expected params, always pass
  }

  // Array of param specs = AND logic (all must match)
  if (Array.isArray(expectedParams)) {
    const results = expectedParams.map((spec, i) =>
      matchParams({
        actualParams,
        expectedParams: spec,
        context: { debug: isLoggingEnabled, _depth: depth + 1 },
        label: `${label}[${i}]`,
      })
    );
    const allPassed = results.every(Boolean);

    if (isLoggingEnabled) {
      blockDebugLogger.logCondition({
        type: "AND",
        args: `${expectedParams.length} ${label} specs`,
        result: allPassed,
        depth,
      });
    }
    return allPassed;
  }

  // OR logic: { any: [...] }
  if (expectedParams.any !== undefined) {
    const specs = expectedParams.any;
    const results = specs.map((spec, i) =>
      matchParams({
        actualParams,
        expectedParams: spec,
        context: { debug: isLoggingEnabled, _depth: depth + 1 },
        label: `${label}[${i}]`,
      })
    );
    const anyPassed = results.some(Boolean);

    if (isLoggingEnabled) {
      blockDebugLogger.logCondition({
        type: "OR",
        args: `${specs.length} ${label} specs`,
        result: anyPassed,
        depth,
      });
    }
    return anyPassed;
  }

  // NOT logic: { not: {...} }
  if (expectedParams.not !== undefined) {
    const innerResult = matchParams({
      actualParams,
      expectedParams: expectedParams.not,
      context: { debug: isLoggingEnabled, _depth: depth + 1 },
      label,
    });
    const result = !innerResult;

    if (isLoggingEnabled) {
      blockDebugLogger.logCondition({
        type: "NOT",
        args: null,
        result,
        depth,
      });
    }
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
  if (isLoggingEnabled) {
    blockDebugLogger.logParamGroup({
      label,
      matches,
      result: allPassed,
      depth,
    });
  }

  return allPassed;
}
