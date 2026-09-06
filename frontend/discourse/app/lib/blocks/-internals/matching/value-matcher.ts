import type { DebugLoggerInterface } from "discourse/lib/blocks/-internals/debug-hooks";
import { findClosestMatch } from "discourse/lib/string-similarity";

/**
 * Evaluation context for `matchParams()`, carrying debug logging state through
 * recursive AND/OR/NOT evaluation.
 */
export interface MatchParamsContext {
  /** Enable debug logging. */
  debug?: boolean;
  /** Nesting depth for logging. */
  _depth?: number;
  /** Logger interface from dev-tools (optional). */
  logger?: DebugLoggerInterface | null;
}

/**
 * Options accepted by `matchParams()`.
 */
export interface MatchParamsOptions {
  /** Current params from router. */
  actualParams?: Record<string, unknown> | null;
  /** Expected params spec. */
  expectedParams?: unknown;
  /** Debug context. */
  context?: MatchParamsContext;
  /** Label for debug output (e.g., "params", "queryParams"). */
  label?: string;
}

/**
 * Evaluates a value matcher spec against an actual value.
 * Supports the same AND/OR/NOT logic as condition evaluation.
 *
 * Supports:
 * - Exact match: `123`, `"foo"`
 * - Array of simple values (OR): `[123, 456]` matches if actual is any of these
 * - Array of complex specs (AND): `[{ not: "a" }, { not: "b" }]` all specs must match
 * - RegExp: `/^foo/` matches if actual matches the pattern
 * - NOT: `{ not: value }` matches if actual does NOT match value
 * - ANY (OR): `{ any: [...] }` matches if actual matches any spec in array
 *
 * @param actual - The actual value to test.
 * @param expected - The expected value spec (exact, array, regex, or AND/OR/NOT spec).
 * @returns True if the actual value matches the expected spec.
 */
export function matchValue({
  actual,
  expected,
}: {
  actual: unknown;
  expected: unknown;
}): boolean {
  // Handle arrays first (before checking for `any`/`not` properties)
  // because Ember prototype extensions add `any()` method to arrays
  if (Array.isArray(expected)) {
    if (expected.length > 0 && !isSimpleValueArray(expected)) {
      // AND logic: Array of non-primitive conditions, all must pass
      return expected.every((exp) => matchValue({ actual, expected: exp }));
    }
    // Simple array of values (OR - match any)
    return matchSimpleValue(actual, expected);
  }

  // OR logic: { any: [...] }
  if ((expected as { any?: unknown[] } | null | undefined)?.any !== undefined) {
    return (expected as { any: unknown[] }).any.some((exp) =>
      matchValue({ actual, expected: exp })
    );
  }

  // NOT logic: { not: ... }
  if ((expected as { not?: unknown } | null | undefined)?.not !== undefined) {
    return !matchValue({
      actual,
      expected: (expected as { not: unknown }).not,
    });
  }

  // Simple value matching (leaf node)
  return matchSimpleValue(actual, expected);
}

/**
 * Checks if an array is a simple value array (for OR matching) vs a condition
 * array (for AND matching). Simple value arrays contain only primitives (strings,
 * numbers, booleans, null, undefined) or RegExp objects.
 *
 * @param arr - The array to check.
 * @returns True if all items are primitives or RegExp.
 */
function isSimpleValueArray(arr: unknown[]): boolean {
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
 * @param actual - The actual value.
 * @param expected - The expected value (primitive, array of primitives/RegExp, or RegExp).
 * @returns True if matches.
 */
function matchSimpleValue(actual: unknown, expected: unknown): boolean {
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
 * @param actual - The actual value.
 * @param expected - The expected value.
 * @returns True if the values would match with type coercion.
 */
export function isTypeMismatch(actual: unknown, expected: unknown): boolean {
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
  if ((expected as { any?: unknown[] } | null | undefined)?.any !== undefined) {
    return (expected as { any: unknown[] }).any.some((exp) =>
      isTypeMismatch(actual, exp)
    );
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
 * @returns True if params match.
 */
export function matchParams({
  actualParams,
  expectedParams,
  context = {},
  label = "params",
}: MatchParamsOptions): boolean {
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
      conditionSpec: expectedParams,
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
    logger?.updateCombinatorResult?.(expectedParams, allPassed);
    return allPassed;
  }

  // OR logic: { any: [...] }
  if ((expectedParams as { any?: unknown[] }).any !== undefined) {
    const specs = (expectedParams as { any: unknown[] }).any;

    // Log combinator BEFORE children so it appears first in tree
    logger?.logCondition?.({
      type: "OR",
      args: `${specs.length} ${label} specs`,
      result: null,
      depth,
      conditionSpec: expectedParams,
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
    logger?.updateCombinatorResult?.(expectedParams, anyPassed);
    return anyPassed;
  }

  // NOT logic: { not: {...} }
  if ((expectedParams as { not?: unknown }).not !== undefined) {
    // Log combinator BEFORE children so it appears first in tree
    logger?.logCondition?.({
      type: "NOT",
      args: null,
      result: null,
      depth,
      conditionSpec: expectedParams,
    });

    const innerResult = matchParams({
      actualParams,
      expectedParams: (expectedParams as { not: unknown }).not,
      context: { debug: isLoggingEnabled, _depth: depth + 1, logger },
      label,
    });
    const result = !innerResult;

    // Update combinator result after children evaluated
    logger?.updateCombinatorResult?.(expectedParams, result);
    return result;
  }

  // Plain object with keys = AND logic across all keys
  // Note: keys starting with \ are escaped (e.g., "\\any" matches literal param "any")
  const expectedParamsRecord = expectedParams as Record<string, unknown>;
  const keys = Object.keys(expectedParamsRecord);
  if (keys.length === 0) {
    return true;
  }

  // Collect match results for debug logging
  const matches: Array<{
    key: string;
    expected: unknown;
    actual: unknown;
    result: boolean;
  }> = [];

  for (const key of keys) {
    // Strip leading backslash for escaped keys (e.g., "\\any" -> "any")
    const actualKey = key.startsWith("\\") ? key.slice(1) : key;
    const expected = expectedParamsRecord[key];
    const actual = actualParams?.[actualKey];
    const result = matchValue({ actual, expected });
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
const VALID_OPERATOR_KEYS: readonly string[] = Object.freeze(["any", "not"]);

/**
 * Validates a param spec for typos in operator keys.
 *
 * Recursively checks that any object key that looks like an operator typo
 * (e.g., "an" instead of "any", "nto" instead of "not") is flagged.
 *
 * @param spec - The param spec to validate.
 * @param path - Current path for error messages.
 * @param raiseError - Function to call with error message.
 */
export function validateParamSpec(
  spec: unknown,
  path: string,
  raiseError: (message: string) => void
): void {
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
  const specRecord = spec as Record<string, unknown>;
  const keys = Object.keys(specRecord);

  for (const key of keys) {
    // Check if this key looks like a typo of a valid operator
    // Skip if it's a valid operator or an escaped key (starts with \)
    if (!VALID_OPERATOR_KEYS.includes(key) && !key.startsWith("\\")) {
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
    validateParamSpec(specRecord[key], `${path}.${key}`, raiseError);
  }
}
