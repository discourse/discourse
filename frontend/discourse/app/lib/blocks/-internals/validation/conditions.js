// @ts-check
import { BlockError } from "discourse/lib/blocks/-internals/error";
import { validateConditionArgValues } from "discourse/lib/blocks/-internals/validation/condition-args";
import {
  runCustomValidation,
  validateConstraints,
} from "discourse/lib/blocks/-internals/validation/constraints";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Regex for validating source path format: `@outletArgs.propertyName` or
 * `@outletArgs.nested.path`.
 */
const OUTLET_ARGS_SOURCE_PATTERN = /^@outletArgs\.[\w.]+$/;

/**
 * Validates the `source` parameter based on the condition's `sourceType`.
 *
 * - `sourceType: "none"`: Returns error if `source` is provided
 * - `sourceType: "outletArgs"`: Validates format is `@outletArgs.propertyPath`
 * - `sourceType: "object"`: Validates `source` is an object if provided
 *
 * @param {"none"|"outletArgs"|"object"} sourceType - The condition's source type.
 * @param {Object} args - The condition arguments from the layout entry.
 * @returns {{ message: string, path?: string } | null} Error info or null if valid.
 */
export function validateConditionSource(sourceType, args) {
  const { source } = args;

  if (source === undefined) {
    return null; // source is always optional
  }

  switch (sourceType) {
    case "none":
      return {
        message: `\`source\` parameter is not supported for this condition type.`,
        path: "source",
      };

    case "outletArgs":
      if (typeof source !== "string") {
        return {
          message: `\`source\` must be a string in format "@outletArgs.propertyName".`,
          path: "source",
        };
      }
      if (!OUTLET_ARGS_SOURCE_PATTERN.test(source)) {
        return {
          message: `\`source\` must be in format "@outletArgs.propertyName", got "${source}".`,
          path: "source",
        };
      }
      break;

    case "object":
      if (source !== null && typeof source !== "object") {
        return {
          message: `\`source\` must be an object.`,
          path: "source",
        };
      }
      break;
  }

  return null;
}

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
  // validArgKeys already includes "source" when sourceType !== "none"
  // (computed by the @blockCondition decorator)
  // @ts-ignore - Static property defined on condition classes
  const validKeys = instance.constructor.validArgKeys;

  for (const key of Object.keys(args)) {
    if (!validKeys.includes(key)) {
      const suggestion = formatWithSuggestion(key, validKeys);
      throw new BlockError(
        `Condition type "${type}": unknown arg ${suggestion}. ` +
          `Valid args: ${validKeys.join(", ")}`,
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
 * Note: Paths are constructed via simple string concatenation (e.g.,
 * `${path}.${key}`, `${path}[${i}]`). Keys are not escaped, so special
 * characters in user-provided keys may cause confusing path displays.
 * This is acceptable since condition keys come from theme/plugin layouts
 * where unusual characters are rare.
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
 * Validation order:
 * 1. Validate unknown args (typo detection) - checked FIRST so typos like "nam"
 *    produce "unknown arg 'nam' (did you mean 'name'?)" instead of "missing required arg 'name'"
 * 2. Validate arg values against schema (type, min/max, pattern, etc.)
 * 3. Validate constraints (atLeastOne, exactlyOne, allOrNone, atMostOne)
 * 4. Validate source parameter (based on sourceType)
 * 5. Run custom validate function from decorator config
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

  // @ts-ignore - Static properties defined on condition classes
  const argsSchema = conditionInstance.constructor.argsSchema;
  // @ts-ignore - Static properties defined on condition classes
  const constraints = conditionInstance.constructor.constraints;
  // @ts-ignore - Static properties defined on condition classes
  const validateFn = conditionInstance.constructor.validateFn;

  // 1. Validate unknown args (catches typos like "nam" instead of "name")
  // This is checked FIRST so typos produce helpful suggestions rather than
  // confusing "missing required arg" errors
  validateConditionArgKeys(conditionInstance, type, args, path);

  // 2. Validate arg values against schema (type, min/max, pattern, etc.)
  if (argsSchema && Object.keys(argsSchema).length > 0) {
    validateConditionArgValues(args, argsSchema, type, path);
  }

  // 3. Validate constraints (atLeastOne, exactlyOne, allOrNone, atMostOne)
  if (constraints) {
    const constraintError = validateConstraints(
      constraints,
      args,
      `Condition "${type}"`
    );
    if (constraintError) {
      // Point to the condition's `type` property so the error location isn't empty.
      // This tells users which condition has the constraint violation.
      const typePath = path ? `${path}.type` : "type";
      throw new BlockError(constraintError, { path: typePath });
    }
  }

  // 4. Validate source parameter (based on sourceType)
  // @ts-ignore - Static property defined on condition classes
  const sourceType = conditionInstance.constructor.sourceType;
  const sourceError = validateConditionSource(sourceType, args);
  if (sourceError) {
    throw new BlockError(sourceError.message, {
      path: sourceError.path ? `${path}.${sourceError.path}` : path,
    });
  }

  // 5. Run custom validate function from decorator config
  if (validateFn) {
    const customErrors = runCustomValidation(validateFn, args);
    if (customErrors?.length > 0) {
      throw new BlockError(`Condition "${type}": ${customErrors.join("; ")}`, {
        path,
      });
    }
  }
}
