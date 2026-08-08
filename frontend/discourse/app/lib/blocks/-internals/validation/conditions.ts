import type { BlockCondition } from "discourse/blocks/conditions";
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

/** The result of `validateConditionSource()`: error info, or `null` if valid. */
export interface ConditionSourceError {
  /** The error message. */
  message: string;
  /** The path to the invalid `source` parameter. */
  path?: string;
}

/**
 * Validates the `source` parameter based on the condition's `sourceType`.
 *
 * - `sourceType: "none"`: Returns error if `source` is provided
 * - `sourceType: "outletArgs"`: Validates format is `@outletArgs.propertyPath`
 * - `sourceType: "object"`: Validates `source` is an object if provided
 *
 * @param sourceType - The condition's source type.
 * @param args - The condition arguments from the layout entry.
 * @returns Error info or null if valid.
 */
export function validateConditionSource(
  sourceType: "none" | "outletArgs" | "object",
  args: Record<string, unknown>
): ConditionSourceError | null {
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
 * @param instance - The condition instance.
 * @param type - The condition type name.
 * @param args - The args provided to the condition.
 * @param path - The path to this condition in the block tree.
 * @throws BlockError if an unrecognized arg key is found.
 */
export function validateConditionArgKeys(
  instance: BlockCondition,
  type: string,
  args: Record<string, unknown>,
  path: string
): void {
  // `instance.constructor` is typed as the generic `Function` by default; the
  // `@blockCondition` decorator always defines `validArgKeys` (and the other
  // statics read throughout this module) on every concrete `BlockCondition`
  // subclass, so this cast reads it safely.
  // validArgKeys already includes "source" when sourceType !== "none"
  // (computed by the @blockCondition decorator)
  const validKeys = (instance.constructor as typeof BlockCondition)
    .validArgKeys;

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
 * @param conditionSpec - Condition spec(s) to validate.
 * @param conditionTypes - Map of registered condition types.
 * @param path - The path to this condition relative to conditions root
 *   (e.g., "", "[0]", "any[1]", "params.categoryId").
 * @throws BlockError if validation fails.
 */
export function validateConditions(
  conditionSpec: unknown,
  conditionTypes: Map<string, BlockCondition>,
  path = ""
): void {
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
  if ((conditionSpec as { any?: unknown[] }).any !== undefined) {
    validateAnyCombinator(
      conditionSpec as { any: unknown[] },
      conditionTypes,
      path
    );
    return;
  }

  // NOT combinator
  if ((conditionSpec as { not?: unknown }).not !== undefined) {
    validateNotCombinator(
      conditionSpec as { not: unknown },
      conditionTypes,
      path
    );
    return;
  }

  // Single condition with type
  validateSingleCondition(
    conditionSpec as { type?: string } & Record<string, unknown>,
    conditionTypes,
    path
  );
}

/**
 * Validates an "any" (OR) combinator.
 *
 * @param conditionSpec - The condition spec containing "any".
 * @param conditionTypes - Map of registered condition types.
 * @param path - The path to this condition in the block tree.
 * @throws BlockError if validation fails.
 */
function validateAnyCombinator(
  conditionSpec: { any: unknown[] },
  conditionTypes: Map<string, BlockCondition>,
  path: string
): void {
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
 * @param conditionSpec - The condition spec containing "not".
 * @param conditionTypes - Map of registered condition types.
 * @param path - The path to this condition in the block tree.
 * @throws BlockError if validation fails.
 */
function validateNotCombinator(
  conditionSpec: { not: unknown },
  conditionTypes: Map<string, BlockCondition>,
  path: string
): void {
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
 * @param conditionSpec - The condition spec with a type property.
 * @param conditionTypes - Map of registered condition types.
 * @param path - The path to this condition in the block tree.
 * @throws BlockError if validation fails.
 */
function validateSingleCondition(
  conditionSpec: { type?: string } & Record<string, unknown>,
  conditionTypes: Map<string, BlockCondition>,
  path: string
): void {
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

  // `conditionInstance.constructor` is typed as the generic `Function` by
  // default; the `@blockCondition` decorator always defines these statics on
  // every concrete `BlockCondition` subclass, so this cast reads them safely.
  const ConditionClass = conditionInstance.constructor as typeof BlockCondition;
  const { argsSchema, constraints, validateFn, sourceType } = ConditionClass;

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
      throw new BlockError(constraintError.message, {
        path: typePath,
        details: constraintError.details,
      });
    }
  }

  // 4. Validate source parameter (based on sourceType)
  const sourceError = validateConditionSource(sourceType, args);
  if (sourceError) {
    throw new BlockError(sourceError.message, {
      path: sourceError.path ? `${path}.${sourceError.path}` : path,
    });
  }

  // 5. Run custom validate function from decorator config
  if (validateFn) {
    const customErrors = runCustomValidation(validateFn, args);
    if (customErrors && customErrors.length > 0) {
      throw new BlockError(`Condition "${type}": ${customErrors.join("; ")}`, {
        path,
      });
    }
  }
}
