/**
 * Cross-arg constraint validation for blocks.
 *
 * This module handles validation rules that span multiple arguments, such as
 * "at least one of these args must be provided" or "these args must be provided together."
 *
 * Supported constraint types:
 * - atLeastOne: At least one of the specified args must be provided
 * - exactlyOne: Exactly one of the specified args must be provided
 * - allOrNone: Either all or none of the specified args must be provided
 * - atMostOne: At most one of the specified args may be provided (0 or 1)
 * - requires: If a dependent arg is provided, its required arg must also be provided
 */
import type {
  ArgSchema,
  BlockConstraints,
  BlockValidateFn,
} from "discourse/blocks/types";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import type { ValidationErrorDetails } from "discourse/lib/blocks/-internals/validation/args";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * A constraint violation: a human-readable message plus a structured detail
 * payload for consumers that surface field-level errors.
 */
interface ConstraintViolation {
  /** The human-readable violation message. */
  message: string;

  /** Structured payload for consumers that surface field-level errors. */
  details: ValidationErrorDetails;
}

/**
 * Builds a structured details payload for a constraint violation.
 *
 * @param constraintType - The constraint type (e.g. "atLeastOne").
 * @param argNames - The arg names participating in the constraint.
 * @returns The structured details payload.
 */
function constraintDetails(
  constraintType: string,
  argNames: string[]
): ValidationErrorDetails {
  return {
    code: ERROR_CODES.CONSTRAINT_VIOLATION,
    expected: { constraint: constraintType, fields: [...argNames] },
  };
}

/**
 * Valid constraint types for cross-arg validation.
 */
export const VALID_CONSTRAINT_TYPES: readonly string[] = Object.freeze([
  "atLeastOne",
  "exactlyOne",
  "allOrNone",
  "atMostOne",
  "requires",
]);

/**
 * Formats an array of arg names as a quoted, comma-separated list.
 *
 * @param argNames - Array of argument names.
 * @returns Formatted string like `"a", "b", "c"`.
 */
function formatArgList(argNames: string[]): string {
  return argNames.map((n) => `"${n}"`).join(", ");
}

/**
 * Validates the constraints schema at decoration time.
 * Checks for:
 * - Valid constraint types
 * - Arg references exist in the args schema
 * - Constraint arrays have at least 2 elements
 * - Incompatible constraints (exactlyOne + allOrNone, exactlyOne + atLeastOne)
 * - Vacuous constraints (constraints rendered always true/false by defaults)
 *
 * @param constraints - The constraints object from decorator options.
 * @param argsSchema - The args schema object from decorator options.
 * @param blockName - Block name for error messages.
 */
export function validateConstraintsSchema(
  constraints: BlockConstraints | null | undefined,
  argsSchema: Record<string, ArgSchema> | null | undefined,
  blockName: string
): void {
  if (!constraints || typeof constraints !== "object") {
    return;
  }

  const declaredArgs = argsSchema ? Object.keys(argsSchema) : [];
  const constraintsByArgs = new Map<string, string[]>();

  for (const [constraintType, argNamesValue] of Object.entries(constraints)) {
    // Check for unknown constraint types with fuzzy matching
    if (!VALID_CONSTRAINT_TYPES.includes(constraintType)) {
      const suggestion = formatWithSuggestion(
        constraintType,
        VALID_CONSTRAINT_TYPES
      );
      raiseBlockError(
        `Block "${blockName}": unknown constraint type ${suggestion}. ` +
          `Valid constraint types are: ${VALID_CONSTRAINT_TYPES.join(", ")}.`
      );
      continue;
    }

    // Handle requires constraint (object format instead of array)
    if (constraintType === "requires") {
      if (
        typeof argNamesValue !== "object" ||
        Array.isArray(argNamesValue) ||
        argNamesValue == null
      ) {
        raiseBlockError(
          `Block "${blockName}": constraint "requires" must be an object mapping dependent args to required args.`
        );
        continue;
      }

      for (const [dependentArg, requiredArg] of Object.entries(argNamesValue)) {
        // Validate dependent arg exists
        if (!declaredArgs.includes(dependentArg)) {
          const suggestion = formatWithSuggestion(dependentArg, declaredArgs);
          raiseBlockError(
            `Block "${blockName}": constraint "requires" references unknown arg ${suggestion}.`
          );
        }
        // Validate required arg is a string
        if (typeof requiredArg !== "string") {
          raiseBlockError(
            `Block "${blockName}": constraint "requires" value for "${dependentArg}" must be a string arg name.`
          );
          continue;
        }
        // Validate required arg exists
        if (!declaredArgs.includes(requiredArg)) {
          const suggestion = formatWithSuggestion(requiredArg, declaredArgs);
          raiseBlockError(
            `Block "${blockName}": constraint "requires" references unknown arg ${suggestion}.`
          );
        }
      }
      continue; // Skip array-based validation for requires
    }

    // Constraint value must be an array
    if (!Array.isArray(argNamesValue)) {
      raiseBlockError(
        `Block "${blockName}": constraint "${constraintType}" must be an array of arg names.`
      );
      continue;
    }

    // The schema authoring contract is an array of arg-name strings; the
    // per-element check just below is defensive against non-TypeScript
    // (plugin/theme) callers passing a malformed array at runtime.
    const argNames = argNamesValue as string[];

    // Constraint array must have at least 2 elements
    if (argNames.length < 2) {
      raiseBlockError(
        `Block "${blockName}": constraint "${constraintType}" must reference at least 2 args.`
      );
      continue;
    }

    // Check that all referenced args exist in the schema
    for (const argName of argNames) {
      if (typeof argName !== "string") {
        raiseBlockError(
          `Block "${blockName}": constraint "${constraintType}" contains non-string value "${argName}".`
        );
        continue;
      }
      if (!declaredArgs.includes(argName)) {
        const suggestion = formatWithSuggestion(argName, declaredArgs);
        raiseBlockError(
          `Block "${blockName}": constraint "${constraintType}" references unknown arg ${suggestion}. ` +
            `Declared args are: ${declaredArgs.join(", ") || "none"}.`
        );
      }
    }

    // Track constraints by their arg sets for incompatibility detection
    const sortedArgs = [...argNames].sort().join(",");
    if (!constraintsByArgs.has(sortedArgs)) {
      constraintsByArgs.set(sortedArgs, []);
    }
    // Guaranteed to be set by the `.has()`/`.set()` pair above.
    constraintsByArgs.get(sortedArgs)!.push(constraintType);

    // Check for vacuous constraints (always true or always false due to defaults)
    if (argsSchema) {
      checkVacuousConstraint(constraintType, argNames, argsSchema, blockName);
    }
  }

  // Check for incompatible constraints on the same args
  for (const [argSet, constraintTypes] of constraintsByArgs) {
    if (constraintTypes.length > 1) {
      checkIncompatibleConstraints(constraintTypes, argSet, blockName);
    }
  }
}

/**
 * Checks if a constraint is vacuous (always true or always false) due to default values.
 *
 * @param constraintType - The constraint type.
 * @param argNames - The arg names in the constraint.
 * @param argsSchema - The args schema.
 * @param blockName - Block name for error messages.
 */
function checkVacuousConstraint(
  constraintType: string,
  argNames: string[],
  argsSchema: Record<string, ArgSchema>,
  blockName: string
): void {
  const argsWithDefaults = argNames.filter(
    (name) => argsSchema[name]?.default !== undefined
  );
  const argsWithoutDefaults = argNames.filter(
    (name) => argsSchema[name]?.default === undefined
  );

  switch (constraintType) {
    case "atLeastOne":
      // Always true if any arg has a default
      if (argsWithDefaults.length > 0) {
        raiseBlockError(
          `Block "${blockName}": constraint atLeastOne([${formatArgList(argNames)}]) ` +
            `is always true because "${argsWithDefaults[0]}" has a default value.`
        );
      }
      break;

    case "exactlyOne":
      // Always false if 2+ args have defaults (both will always be provided)
      if (argsWithDefaults.length >= 2) {
        raiseBlockError(
          `Block "${blockName}": constraint exactlyOne([${formatArgList(argNames)}]) ` +
            `is always false because multiple args have default values: ${formatArgList(argsWithDefaults)}.`
        );
      }
      // Always true if exactly one arg has a default and all others have no default
      // (the one with default is always provided, others never are unless explicitly set)
      // This is NOT vacuous - it's a valid constraint that forces users to not provide
      // any of the other args, or to provide exactly one of the non-default args
      break;

    case "allOrNone":
      // Always false if some but not all args have defaults
      if (argsWithDefaults.length > 0 && argsWithoutDefaults.length > 0) {
        raiseBlockError(
          `Block "${blockName}": constraint allOrNone([${formatArgList(argNames)}]) ` +
            `is always false because only some args have defaults: ${formatArgList(argsWithDefaults)} ` +
            `have defaults but ${formatArgList(argsWithoutDefaults)} do not.`
        );
      }
      // If all have defaults or none have defaults, constraint is not vacuous
      break;

    case "atMostOne":
      // Always false if 2+ args have defaults (both will always be provided)
      if (argsWithDefaults.length >= 2) {
        raiseBlockError(
          `Block "${blockName}": constraint atMostOne([${formatArgList(argNames)}]) ` +
            `is always false because multiple args have default values: ${formatArgList(argsWithDefaults)}.`
        );
      }
      break;
  }
}

/**
 * Checks for incompatible constraint types on the same arg set.
 *
 * @param constraintTypes - The constraint types applied to the same args.
 * @param argSet - The sorted arg names (for error message).
 * @param blockName - Block name for error messages.
 */
function checkIncompatibleConstraints(
  constraintTypes: string[],
  argSet: string,
  blockName: string
): void {
  const argList = argSet
    .split(",")
    .map((n) => `"${n}"`)
    .join(", ");

  // exactlyOne + allOrNone = contradiction (XOR vs all-or-nothing)
  if (
    constraintTypes.includes("exactlyOne") &&
    constraintTypes.includes("allOrNone")
  ) {
    raiseBlockError(
      `Block "${blockName}": constraints "exactlyOne" and "allOrNone" conflict for args [${argList}]. ` +
        `"exactlyOne" requires exactly one arg, but "allOrNone" requires all or none.`
    );
  }

  // exactlyOne + atLeastOne = redundant (exactlyOne implies atLeastOne)
  if (
    constraintTypes.includes("exactlyOne") &&
    constraintTypes.includes("atLeastOne")
  ) {
    raiseBlockError(
      `Block "${blockName}": constraint "atLeastOne" is redundant with "exactlyOne" for args [${argList}]. ` +
        `"exactlyOne" already implies at least one must be provided.`
    );
  }

  // atMostOne + atLeastOne = redundant (equivalent to exactlyOne)
  if (
    constraintTypes.includes("atMostOne") &&
    constraintTypes.includes("atLeastOne")
  ) {
    raiseBlockError(
      `Block "${blockName}": constraints "atMostOne" and "atLeastOne" together for args [${argList}] ` +
        `are equivalent to "exactlyOne". Use "exactlyOne" instead.`
    );
  }

  // atMostOne + exactlyOne = redundant (exactlyOne implies atMostOne)
  if (
    constraintTypes.includes("atMostOne") &&
    constraintTypes.includes("exactlyOne")
  ) {
    raiseBlockError(
      `Block "${blockName}": constraint "atMostOne" is redundant with "exactlyOne" for args [${argList}]. ` +
        `"exactlyOne" already implies at most one may be provided.`
    );
  }
}

/**
 * Validates constraints against the provided args at runtime.
 * Called after defaults are applied.
 *
 * Returns an object with the human-readable message AND a structured
 * `details` payload (for consumers that surface field-level errors) on the
 * first violation, or `null` if all constraints pass.
 *
 * @param constraints - The constraints from block metadata.
 * @param args - The resolved args (with defaults applied).
 * @param blockName - Block name for error messages.
 * @returns The first constraint violation, or `null` if every constraint passes.
 */
export function validateConstraints(
  constraints: BlockConstraints | null | undefined,
  args: Record<string, unknown>,
  blockName: string
): ConstraintViolation | null {
  if (!constraints || typeof constraints !== "object") {
    return null;
  }

  for (const [constraintType, argNamesValue] of Object.entries(constraints)) {
    let error: ConstraintViolation | null = null;

    // Handle requires constraint (object format)
    if (constraintType === "requires") {
      if (
        typeof argNamesValue === "object" &&
        argNamesValue !== null &&
        !Array.isArray(argNamesValue)
      ) {
        error = validateRequires(
          argNamesValue as Record<string, string>,
          args,
          blockName
        );
      }
    } else if (Array.isArray(argNamesValue)) {
      // Handle array-based constraints
      const argNames = argNamesValue as string[];
      switch (constraintType) {
        case "atLeastOne":
          error = validateAtLeastOne(argNames, args, blockName);
          break;
        case "exactlyOne":
          error = validateExactlyOne(argNames, args, blockName);
          break;
        case "allOrNone":
          error = validateAllOrNone(argNames, args, blockName);
          break;
        case "atMostOne":
          error = validateAtMostOne(argNames, args, blockName);
          break;
      }
    }

    if (error) {
      return error;
    }
  }

  return null;
}

/**
 * Validates that at least one of the specified args is provided.
 *
 * @param argNames - The arg names to check.
 * @param args - The resolved args.
 * @param blockName - The block name for error messages.
 * @returns The constraint violation, or `null` if it passes.
 */
function validateAtLeastOne(
  argNames: string[],
  args: Record<string, unknown>,
  blockName: string
): ConstraintViolation | null {
  const providedCount = argNames.filter(
    (name) => args[name] !== undefined
  ).length;

  if (providedCount === 0) {
    const argList = formatArgList(argNames);
    return {
      message: `Block "${blockName}": at least one of ${argList} must be provided.`,
      details: constraintDetails("atLeastOne", argNames),
    };
  }

  return null;
}

/**
 * Validates that exactly one of the specified args is provided.
 *
 * @param argNames - The arg names to check.
 * @param args - The resolved args.
 * @param blockName - The block name for error messages.
 * @returns The constraint violation, or `null` if it passes.
 */
function validateExactlyOne(
  argNames: string[],
  args: Record<string, unknown>,
  blockName: string
): ConstraintViolation | null {
  const providedArgs = argNames.filter((name) => args[name] !== undefined);
  const argList = formatArgList(argNames);

  if (providedArgs.length === 0) {
    return {
      message: `Block "${blockName}": exactly one of ${argList} must be provided, but got none.`,
      details: constraintDetails("exactlyOne", argNames),
    };
  }

  if (providedArgs.length > 1) {
    const providedList = formatArgList(providedArgs);
    return {
      message: `Block "${blockName}": exactly one of ${argList} must be provided, but got ${providedArgs.length}: ${providedList}.`,
      details: constraintDetails("exactlyOne", argNames),
    };
  }

  return null;
}

/**
 * Validates that either all or none of the specified args are provided.
 *
 * @param argNames - The arg names to check.
 * @param args - The resolved args.
 * @param blockName - The block name for error messages.
 * @returns The constraint violation, or `null` if it passes.
 */
function validateAllOrNone(
  argNames: string[],
  args: Record<string, unknown>,
  blockName: string
): ConstraintViolation | null {
  const providedCount = argNames.filter(
    (name) => args[name] !== undefined
  ).length;

  // Valid: all provided or none provided
  if (providedCount === 0 || providedCount === argNames.length) {
    return null;
  }

  // Invalid: some but not all
  const providedArgs = argNames.filter((name) => args[name] !== undefined);
  const missingArgs = argNames.filter((name) => args[name] === undefined);
  const argList = formatArgList(argNames);

  return {
    message:
      `Block "${blockName}": args ${argList} must be provided together or not at all. ` +
      `Got ${formatArgList(providedArgs)} but missing ${formatArgList(missingArgs)}.`,
    details: constraintDetails("allOrNone", argNames),
  };
}

/**
 * Validates that at most one of the specified args is provided (0 or 1).
 *
 * @param argNames - The arg names to check.
 * @param args - The resolved args.
 * @param blockName - The block name for error messages.
 * @returns The constraint violation, or `null` if it passes.
 */
function validateAtMostOne(
  argNames: string[],
  args: Record<string, unknown>,
  blockName: string
): ConstraintViolation | null {
  const providedArgs = argNames.filter((name) => args[name] !== undefined);

  if (providedArgs.length > 1) {
    const providedList = formatArgList(providedArgs);
    const argList = formatArgList(argNames);
    return {
      message: `Block "${blockName}": at most one of ${argList} may be provided, but got ${providedArgs.length}: ${providedList}.`,
      details: constraintDetails("atMostOne", argNames),
    };
  }

  return null;
}

/**
 * Validates that if a dependent arg is provided, its required arg must also be provided.
 *
 * @param requiresMap - Object mapping dependent args to required args.
 * @param args - The resolved args.
 * @param blockName - The block name for error messages.
 * @returns The constraint violation, or `null` if it passes.
 */
function validateRequires(
  requiresMap: Record<string, string>,
  args: Record<string, unknown>,
  blockName: string
): ConstraintViolation | null {
  for (const [dependentArg, requiredArg] of Object.entries(requiresMap)) {
    if (args[dependentArg] !== undefined && args[requiredArg] === undefined) {
      return {
        message: `Block "${blockName}": "${dependentArg}" requires "${requiredArg}" to be specified.`,
        details: constraintDetails("requires", [dependentArg, requiredArg]),
      };
    }
  }
  return null;
}

/**
 * Runs a custom validation function if provided.
 *
 * @param validateFn - The custom validate function.
 * @param args - The resolved args (with defaults applied).
 * @returns Array of error messages if validation fails, null otherwise.
 */
export function runCustomValidation(
  validateFn: BlockValidateFn | null | undefined,
  args: Record<string, unknown>
): string[] | null {
  if (typeof validateFn !== "function") {
    return null;
  }

  const result = validateFn(args);

  if (result == null) {
    return null;
  }

  // Normalize to array
  if (typeof result === "string") {
    return [result];
  }

  if (Array.isArray(result)) {
    // `Array.isArray()` narrows to the (necessarily untyped) built-in `any[]`;
    // re-declare it as `unknown[]` so nothing downstream carries an `any`.
    const resultArray = result as unknown[];
    // Filter out non-string values and empty strings
    const errors = resultArray.filter(
      (e): e is string => typeof e === "string" && e.length > 0
    );
    return errors.length > 0 ? errors : null;
  }

  // Invalid return type - ignore
  return null;
}
