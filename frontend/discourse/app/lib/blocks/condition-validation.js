// @ts-check
import { BlockError } from "discourse/lib/blocks/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Validates that all provided args are recognized by a condition.
 * Suggests corrections for typos using fuzzy string matching.
 *
 * @param {import("discourse/blocks/conditions").BlockCondition} instance - The condition instance.
 * @param {string} type - The condition type name.
 * @param {Object} args - The args provided to the condition.
 * @param {string} path - The path to this condition in the block tree.
 * @throws {BlockError} If an unrecognized arg key is found.
 */
export function validateConditionArgKeys(instance, type, args, path) {
  // @ts-ignore - Static property defined on condition classes
  const validKeys = instance.constructor.validArgKeys;

  // source is always valid if sourceType allows it
  // @ts-ignore - Static property defined on condition classes
  const sourceType = instance.constructor.sourceType;
  const allValidKeys =
    sourceType !== "none" ? [...validKeys, "source"] : validKeys;

  for (const key of Object.keys(args)) {
    if (!allValidKeys.includes(key)) {
      const suggestion = formatWithSuggestion(key, allValidKeys);
      throw new BlockError(
        `Condition type "${type}": unknown arg ${suggestion}. ` +
          `Valid args: ${allValidKeys.join(", ")}`,
        { path: path ? `${path}.${key}` : key }
      );
    }
  }
}

/**
 * Validates condition specs at block registration time.
 * Recursively validates nested conditions in `any` and `not` combinators.
 *
 * Throws BlockError objects with a `path` property indicating where in the
 * conditions the error occurred. Callers can use this path combined with
 * their context path to build full error location.
 *
 * @param {Object|Array<Object>} conditionSpec - Condition spec(s) to validate.
 * @param {Map<string, import("discourse/blocks/conditions").BlockCondition>} conditionTypes - Map of registered condition types.
 * @param {string} [path=""] - The path to this condition relative to conditions root
 *   (e.g., "", "[0]", "any[1]", "params.categoryId").
 * @throws {BlockError} If validation fails.
 */
export function validateConditions(conditionSpec, conditionTypes, path = "") {
  if (!conditionSpec) {
    return;
  }

  // Array of conditions (AND logic)
  if (Array.isArray(conditionSpec)) {
    for (let i = 0; i < conditionSpec.length; i++) {
      validateConditions(conditionSpec[i], conditionTypes, `${path}[${i}]`);
    }
    return;
  }

  // OR combinator
  if (conditionSpec.any !== undefined) {
    validateAnyCombinator(conditionSpec, conditionTypes, path);
    return;
  }

  // NOT combinator
  if (conditionSpec.not !== undefined) {
    validateNotCombinator(conditionSpec, conditionTypes, path);
    return;
  }

  // Single condition with type
  validateSingleCondition(conditionSpec, conditionTypes, path);
}

/**
 * Validates an "any" (OR) combinator.
 *
 * @param {Object} conditionSpec - The condition spec containing "any".
 * @param {Map<string, import("discourse/blocks/conditions").BlockCondition>} conditionTypes - Map of registered condition types.
 * @param {string} path - The path to this condition in the block tree.
 * @throws {BlockError} If validation fails.
 */
function validateAnyCombinator(conditionSpec, conditionTypes, path) {
  // Validate no extra keys alongside "any"
  const extraKeys = Object.keys(conditionSpec).filter((k) => k !== "any");
  if (extraKeys.length > 0) {
    throw new BlockError(
      `"any" combinator has extra keys: ${extraKeys.join(", ")}. ` +
        `Only "any" is allowed.`,
      { path }
    );
  }

  if (!Array.isArray(conditionSpec.any)) {
    throw new BlockError('"any" must be an array of conditions', {
      path: `${path}.any`,
    });
  }

  for (let i = 0; i < conditionSpec.any.length; i++) {
    validateConditions(
      conditionSpec.any[i],
      conditionTypes,
      `${path}.any[${i}]`
    );
  }
}

/**
 * Validates a "not" (NOT) combinator.
 *
 * @param {Object} conditionSpec - The condition spec containing "not".
 * @param {Map<string, import("discourse/blocks/conditions").BlockCondition>} conditionTypes - Map of registered condition types.
 * @param {string} path - The path to this condition in the block tree.
 * @throws {BlockError} If validation fails.
 */
function validateNotCombinator(conditionSpec, conditionTypes, path) {
  // Validate no extra keys alongside "not"
  const extraKeys = Object.keys(conditionSpec).filter((k) => k !== "not");
  if (extraKeys.length > 0) {
    throw new BlockError(
      `"not" combinator has extra keys: ${extraKeys.join(", ")}. ` +
        `Only "not" is allowed.`,
      { path }
    );
  }

  if (
    typeof conditionSpec.not !== "object" ||
    Array.isArray(conditionSpec.not)
  ) {
    throw new BlockError('"not" must be a single condition object', {
      path: `${path}.not`,
    });
  }

  validateConditions(conditionSpec.not, conditionTypes, `${path}.not`);
}

/**
 * Validates a single condition with a type property.
 *
 * @param {Object} conditionSpec - The condition spec with a type property.
 * @param {Map<string, import("discourse/blocks/conditions").BlockCondition>} conditionTypes - Map of registered condition types.
 * @param {string} path - The path to this condition in the block tree.
 * @throws {BlockError} If validation fails.
 */
function validateSingleCondition(conditionSpec, conditionTypes, path) {
  const { type, ...args } = conditionSpec;

  if (!type) {
    throw new BlockError(
      `Condition is missing "type" property: ${JSON.stringify(conditionSpec)}`,
      { path: path || undefined }
    );
  }

  const conditionInstance = conditionTypes.get(type);

  if (!conditionInstance) {
    const availableTypes = [...conditionTypes.keys()];
    const suggestion = formatWithSuggestion(type, availableTypes);
    throw new BlockError(
      `Unknown condition type: ${suggestion}. Available types: ${availableTypes.join(", ")}`,
      { path: path ? `${path}.type` : "type" }
    );
  }

  // Validate arg keys (catches typos like "querParams" instead of "queryParams")
  validateConditionArgKeys(conditionInstance, type, args, path);

  // Run the condition's own validation - returns error info or null
  const error = conditionInstance.validate(args);
  if (error) {
    // Build full path: combine condition path with error's relative path
    let fullPath;
    if (error.path) {
      fullPath = path ? `${path}.${error.path}` : error.path;
    } else {
      fullPath = path || undefined;
    }
    throw new BlockError(error.message, { path: fullPath });
  }
}
