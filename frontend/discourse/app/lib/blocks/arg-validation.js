import {
  BlockValidationError,
  raiseBlockError,
} from "discourse/lib/blocks/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Valid arg name pattern: must be a valid JavaScript identifier.
 * Starts with a letter, followed by letters, numbers, or underscores.
 * Note: Names starting with underscore are reserved for internal use.
 */
const VALID_ARG_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9_]*$/;

/**
 * Valid arg types for block metadata schema.
 */
export const VALID_ARG_TYPES = Object.freeze([
  "string",
  "number",
  "boolean",
  "array",
]);

/**
 * Valid item types for array args.
 */
export const VALID_ITEM_TYPES = Object.freeze(["string", "number", "boolean"]);

/**
 * Valid properties for arg schema definitions.
 */
export const VALID_ARG_SCHEMA_PROPERTIES = Object.freeze([
  "type",
  "required",
  "default",
  "itemType",
  "pattern",
  "minLength",
  "maxLength",
  "min",
  "max",
  "integer",
  "enum",
]);

/**
 * Valid constraint types for cross-arg validation.
 */
export const VALID_CONSTRAINT_TYPES = Object.freeze([
  "atLeastOne",
  "exactlyOne",
  "allOrNone",
]);

/**
 * Validates the arg schema definition passed to the @block decorator.
 * Enforces strict schema format - unknown properties are not allowed.
 *
 * @param {Object} argsSchema - The args schema object from decorator options
 * @param {string} blockName - Block name for error messages
 * @throws {Error} If schema is invalid
 */
export function validateArgsSchema(argsSchema, blockName) {
  if (!argsSchema || typeof argsSchema !== "object") {
    return;
  }

  for (const [argName, argDef] of Object.entries(argsSchema)) {
    // Validate arg name format
    if (!VALID_ARG_NAME_PATTERN.test(argName)) {
      raiseBlockError(
        `Block "${blockName}": arg name "${argName}" is invalid. ` +
          `Arg names must start with a letter and contain only letters, numbers, and underscores.`
      );
      continue;
    }

    if (!argDef || typeof argDef !== "object") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" must be an object with a "type" property.`
      );
      continue;
    }

    // Check for unknown properties
    const unknownProps = Object.keys(argDef).filter(
      (prop) => !VALID_ARG_SCHEMA_PROPERTIES.includes(prop)
    );
    if (unknownProps.length > 0) {
      const suggestions = unknownProps.map((prop) =>
        formatWithSuggestion(prop, VALID_ARG_SCHEMA_PROPERTIES)
      );
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has unknown properties: ${suggestions.join(", ")}. ` +
          `Valid properties are: ${VALID_ARG_SCHEMA_PROPERTIES.join(", ")}.`
      );
    }

    // Type is required
    if (!argDef.type) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" is missing required "type" property.`
      );
      continue;
    }

    // Validate type
    if (!VALID_ARG_TYPES.includes(argDef.type)) {
      const suggestion = formatWithSuggestion(argDef.type, VALID_ARG_TYPES);
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid type ${suggestion}. ` +
          `Valid types are: ${VALID_ARG_TYPES.join(", ")}.`
      );
    }

    // itemType is only valid for array type
    if (argDef.itemType !== undefined && argDef.type !== "array") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "itemType" but type is "${argDef.type}". ` +
          `"itemType" is only valid for array type.`
      );
    }

    // Validate itemType for arrays
    if (argDef.type === "array" && argDef.itemType !== undefined) {
      if (!VALID_ITEM_TYPES.includes(argDef.itemType)) {
        const suggestion = formatWithSuggestion(
          argDef.itemType,
          VALID_ITEM_TYPES
        );
        raiseBlockError(
          `Block "${blockName}": arg "${argName}" has invalid itemType ${suggestion}. ` +
            `Valid item types are: ${VALID_ITEM_TYPES.join(", ")}.`
        );
      }
    }

    // pattern is only valid for string type
    if (argDef.pattern !== undefined && argDef.type !== "string") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "pattern" but type is "${argDef.type}". ` +
          `"pattern" is only valid for string type.`
      );
    }

    // Validate pattern is a RegExp
    if (argDef.pattern !== undefined && !(argDef.pattern instanceof RegExp)) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "pattern" value. Must be a RegExp.`
      );
    }

    // min is only valid for number type
    if (argDef.min !== undefined && argDef.type !== "number") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "min" but type is "${argDef.type}". ` +
          `"min" is only valid for number type.`
      );
    }

    // Validate min is a number
    if (argDef.min !== undefined && typeof argDef.min !== "number") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "min" value. Must be a number.`
      );
    }

    // max is only valid for number type
    if (argDef.max !== undefined && argDef.type !== "number") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "max" but type is "${argDef.type}". ` +
          `"max" is only valid for number type.`
      );
    }

    // Validate max is a number
    if (argDef.max !== undefined && typeof argDef.max !== "number") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "max" value. Must be a number.`
      );
    }

    // Validate min <= max
    if (
      argDef.min !== undefined &&
      argDef.max !== undefined &&
      argDef.min > argDef.max
    ) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has min (${argDef.min}) greater than max (${argDef.max}).`
      );
    }

    // integer is only valid for number type
    if (argDef.integer !== undefined && argDef.type !== "number") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "integer" but type is "${argDef.type}". ` +
          `"integer" is only valid for number type.`
      );
    }

    // Validate integer is a boolean
    if (argDef.integer !== undefined && typeof argDef.integer !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "integer" value. Must be a boolean.`
      );
    }

    // minLength is only valid for string or array type
    if (
      argDef.minLength !== undefined &&
      argDef.type !== "string" &&
      argDef.type !== "array"
    ) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "minLength" but type is "${argDef.type}". ` +
          `"minLength" is only valid for string or array type.`
      );
    }

    // Validate minLength is a non-negative integer
    if (
      argDef.minLength !== undefined &&
      (!Number.isInteger(argDef.minLength) || argDef.minLength < 0)
    ) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "minLength" value. Must be a non-negative integer.`
      );
    }

    // maxLength is only valid for string or array type
    if (
      argDef.maxLength !== undefined &&
      argDef.type !== "string" &&
      argDef.type !== "array"
    ) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "maxLength" but type is "${argDef.type}". ` +
          `"maxLength" is only valid for string or array type.`
      );
    }

    // Validate maxLength is a non-negative integer
    if (
      argDef.maxLength !== undefined &&
      (!Number.isInteger(argDef.maxLength) || argDef.maxLength < 0)
    ) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "maxLength" value. Must be a non-negative integer.`
      );
    }

    // Validate minLength <= maxLength
    if (
      argDef.minLength !== undefined &&
      argDef.maxLength !== undefined &&
      argDef.minLength > argDef.maxLength
    ) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has minLength (${argDef.minLength}) greater than maxLength (${argDef.maxLength}).`
      );
    }

    // enum is only valid for string or number type
    if (
      argDef.enum !== undefined &&
      argDef.type !== "string" &&
      argDef.type !== "number"
    ) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has "enum" but type is "${argDef.type}". ` +
          `"enum" is only valid for string or number type.`
      );
    }

    // Validate enum is an array with at least one element
    if (argDef.enum !== undefined) {
      if (!Array.isArray(argDef.enum) || argDef.enum.length === 0) {
        raiseBlockError(
          `Block "${blockName}": arg "${argName}" has invalid "enum" value. Must be an array with at least one element.`
        );
      } else {
        // Validate all enum values match the arg type
        const expectedType = argDef.type === "string" ? "string" : "number";
        for (const enumValue of argDef.enum) {
          if (typeof enumValue !== expectedType) {
            raiseBlockError(
              `Block "${blockName}": arg "${argName}" enum contains invalid value "${enumValue}". All values must be ${expectedType}s.`
            );
          }
        }
      }
    }

    // Validate required is boolean
    if (argDef.required !== undefined && typeof argDef.required !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "required" value. Must be a boolean.`
      );
    }

    // required + default is contradictory - default makes required meaningless
    if (argDef.required === true && argDef.default !== undefined) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has both "required: true" and "default". ` +
          `These options are contradictory - an arg with a default value is never missing.`
      );
    }

    // Validate default value matches type
    if (argDef.default !== undefined) {
      const defaultError = validateArgValue(
        argDef.default,
        argDef,
        argName,
        blockName
      );
      if (defaultError) {
        raiseBlockError(
          `Block "${blockName}": arg "${argName}" has invalid default value. ${defaultError}`
        );
      }
    }
  }
}

/**
 * Validates a single argument value against its schema definition.
 *
 * @param {*} value - The argument value
 * @param {Object} argSchema - The schema definition for this arg
 * @param {string} argName - The argument name for error messages
 * @param {string} blockName - The block name for error messages
 * @returns {string|null} Error message if validation fails, null otherwise
 */
export function validateArgValue(value, argSchema, argName, blockName) {
  const {
    type,
    itemType,
    pattern,
    minLength,
    maxLength,
    min,
    max,
    integer,
    enum: enumValues,
  } = argSchema;

  // Skip validation if value is undefined (handled by required check)
  if (value === undefined) {
    return null;
  }

  switch (type) {
    case "string":
      if (typeof value !== "string") {
        return `Block "${blockName}": arg "${argName}" must be a string, got ${typeof value}.`;
      }
      // Validate against pattern if specified
      if (pattern && !pattern.test(value)) {
        return `Block "${blockName}": arg "${argName}" value "${value}" does not match required pattern ${pattern}.`;
      }
      // Validate minLength constraint
      if (minLength !== undefined && value.length < minLength) {
        return `Block "${blockName}": arg "${argName}" must be at least ${minLength} characters, got ${value.length}.`;
      }
      // Validate maxLength constraint
      if (maxLength !== undefined && value.length > maxLength) {
        return `Block "${blockName}": arg "${argName}" must be at most ${maxLength} characters, got ${value.length}.`;
      }
      // Validate enum constraint
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return `Block "${blockName}": arg "${argName}" must be one of: ${enumValues.map((v) => `"${v}"`).join(", ")}. Got "${value}".`;
      }
      break;

    case "number":
      if (typeof value !== "number" || Number.isNaN(value)) {
        return `Block "${blockName}": arg "${argName}" must be a number, got ${typeof value}.`;
      }
      // Validate integer constraint
      if (integer && !Number.isInteger(value)) {
        return `Block "${blockName}": arg "${argName}" must be an integer, got ${value}.`;
      }
      // Validate min constraint
      if (min !== undefined && value < min) {
        return `Block "${blockName}": arg "${argName}" must be at least ${min}, got ${value}.`;
      }
      // Validate max constraint
      if (max !== undefined && value > max) {
        return `Block "${blockName}": arg "${argName}" must be at most ${max}, got ${value}.`;
      }
      // Validate enum constraint
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return `Block "${blockName}": arg "${argName}" must be one of: ${enumValues.join(", ")}. Got ${value}.`;
      }
      break;

    case "boolean":
      if (typeof value !== "boolean") {
        return `Block "${blockName}": arg "${argName}" must be a boolean, got ${typeof value}.`;
      }
      break;

    case "array":
      if (!Array.isArray(value)) {
        return `Block "${blockName}": arg "${argName}" must be an array, got ${typeof value}.`;
      }
      // Validate minLength constraint
      if (minLength !== undefined && value.length < minLength) {
        return `Block "${blockName}": arg "${argName}" must have at least ${minLength} items, got ${value.length}.`;
      }
      // Validate maxLength constraint
      if (maxLength !== undefined && value.length > maxLength) {
        return `Block "${blockName}": arg "${argName}" must have at most ${maxLength} items, got ${value.length}.`;
      }

      // Validate item types if specified
      if (itemType) {
        for (let i = 0; i < value.length; i++) {
          const item = value[i];
          const itemError = validateArrayItemType(
            item,
            itemType,
            argName,
            blockName,
            i
          );
          if (itemError) {
            return itemError;
          }
        }
      }
      break;
  }

  return null;
}

/**
 * Validates an array item against the specified item type.
 *
 * @param {*} item - The array item
 * @param {string} itemType - The expected type ("string", "number", "boolean")
 * @param {string} argName - The argument name for error messages
 * @param {string} blockName - The block name for error messages
 * @param {number} index - The array index for error messages
 * @returns {string|null} Error message if validation fails, null otherwise
 */
export function validateArrayItemType(
  item,
  itemType,
  argName,
  blockName,
  index
) {
  switch (itemType) {
    case "string":
      if (typeof item !== "string") {
        return `Block "${blockName}": arg "${argName}[${index}]" must be a string, got ${typeof item}.`;
      }
      break;

    case "number":
      if (typeof item !== "number" || Number.isNaN(item)) {
        return `Block "${blockName}": arg "${argName}[${index}]" must be a number, got ${typeof item}.`;
      }
      break;

    case "boolean":
      if (typeof item !== "boolean") {
        return `Block "${blockName}": arg "${argName}[${index}]" must be a boolean, got ${typeof item}.`;
      }
      break;
  }

  return null;
}

/**
 * Validates block arguments against the block's metadata arg schema.
 * Checks for required args and validates types.
 *
 * @param {Object} config - The block configuration.
 * @param {Object} blockClass - The resolved block class (must be a class, not a string reference).
 * @throws {BlockValidationError} If args are invalid.
 */
export function validateBlockArgs(config, blockClass) {
  const metadata = blockClass?.blockMetadata;
  const providedArgs = config.args || {};
  const hasProvidedArgs = Object.keys(providedArgs).length > 0;
  const argsSchema = metadata?.args;

  // If args are provided but no schema exists, reject them
  if (hasProvidedArgs && !argsSchema) {
    const argNames = Object.keys(providedArgs).join(", ");
    throw new BlockValidationError(
      `args were provided (${argNames}) but this block does not declare an args schema. ` +
        `Add an args schema to the @block decorator or remove the args.`,
      "args"
    );
  }

  // No schema and no args - nothing to validate
  if (!argsSchema) {
    return;
  }

  for (const [argName, argDef] of Object.entries(argsSchema)) {
    const value = providedArgs[argName];

    // Check required args
    if (argDef.required && value === undefined) {
      throw new BlockValidationError(
        `missing required arg "${argName}".`,
        `args.${argName}`
      );
    }

    // Validate type if value is provided
    if (value !== undefined) {
      const typeError = validateArgValueForSchema(value, argDef, argName);
      if (typeError) {
        throw new BlockValidationError(typeError, `args.${argName}`);
      }
    }
  }

  // Check for unknown args (args provided but not in schema)
  const declaredArgs = Object.keys(argsSchema);
  for (const argName of Object.keys(providedArgs)) {
    if (!Object.hasOwn(argsSchema, argName)) {
      const suggestion = formatWithSuggestion(argName, declaredArgs);
      throw new BlockValidationError(
        `unknown arg ${suggestion}. Declared args are: ${declaredArgs.join(", ") || "none"}.`,
        `args.${argName}`
      );
    }
  }
}

/**
 * Validates a single argument value against its schema definition.
 * Returns an error message string (for use with BlockValidationError).
 *
 * @param {*} value - The argument value.
 * @param {Object} argSchema - The schema definition for this arg.
 * @param {string} argName - The argument name for error messages.
 * @returns {string | null} Error message if validation fails, null otherwise.
 */
function validateArgValueForSchema(value, argSchema, argName) {
  const {
    type,
    itemType,
    pattern,
    minLength,
    maxLength,
    min,
    max,
    integer,
    enum: enumValues,
  } = argSchema;

  switch (type) {
    case "string":
      if (typeof value !== "string") {
        return `Arg "${argName}" must be a string, got ${typeof value}.`;
      }
      if (pattern && !pattern.test(value)) {
        return `Arg "${argName}" value "${value}" does not match required pattern ${pattern}.`;
      }
      if (minLength !== undefined && value.length < minLength) {
        return `Arg "${argName}" must be at least ${minLength} characters, got ${value.length}.`;
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return `Arg "${argName}" must be at most ${maxLength} characters, got ${value.length}.`;
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return `Arg "${argName}" must be one of: ${enumValues.map((v) => `"${v}"`).join(", ")}. Got "${value}".`;
      }
      break;

    case "number":
      if (typeof value !== "number" || Number.isNaN(value)) {
        return `Arg "${argName}" must be a number, got ${typeof value}.`;
      }
      if (integer && !Number.isInteger(value)) {
        return `Arg "${argName}" must be an integer, got ${value}.`;
      }
      if (min !== undefined && value < min) {
        return `Arg "${argName}" must be at least ${min}, got ${value}.`;
      }
      if (max !== undefined && value > max) {
        return `Arg "${argName}" must be at most ${max}, got ${value}.`;
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return `Arg "${argName}" must be one of: ${enumValues.join(", ")}. Got ${value}.`;
      }
      break;

    case "boolean":
      if (typeof value !== "boolean") {
        return `Arg "${argName}" must be a boolean, got ${typeof value}.`;
      }
      break;

    case "array":
      if (!Array.isArray(value)) {
        return `Arg "${argName}" must be an array, got ${typeof value}.`;
      }
      if (minLength !== undefined && value.length < minLength) {
        return `Arg "${argName}" must have at least ${minLength} items, got ${value.length}.`;
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return `Arg "${argName}" must have at most ${maxLength} items, got ${value.length}.`;
      }
      if (itemType) {
        for (let i = 0; i < value.length; i++) {
          const item = value[i];
          const itemError = validateArrayItemTypeForSchema(
            item,
            itemType,
            argName,
            i
          );
          if (itemError) {
            return itemError;
          }
        }
      }
      break;
  }

  return null;
}

/**
 * Validates an array item against the specified item type.
 * Returns an error message string (for use with BlockValidationError).
 *
 * @param {*} item - The array item.
 * @param {string} itemType - The expected type ("string", "number", "boolean").
 * @param {string} argName - The argument name for error messages.
 * @param {number} index - The array index for error messages.
 * @returns {string | null} Error message if validation fails, null otherwise.
 */
function validateArrayItemTypeForSchema(item, itemType, argName, index) {
  switch (itemType) {
    case "string":
      if (typeof item !== "string") {
        return `Arg "${argName}[${index}]" must be a string, got ${typeof item}.`;
      }
      break;

    case "number":
      if (typeof item !== "number" || Number.isNaN(item)) {
        return `Arg "${argName}[${index}]" must be a number, got ${typeof item}.`;
      }
      break;

    case "boolean":
      if (typeof item !== "boolean") {
        return `Arg "${argName}[${index}]" must be a boolean, got ${typeof item}.`;
      }
      break;
  }

  return null;
}

/* ============================================================================
 * Constraint Validation
 * ============================================================================
 * Cross-arg constraints allow validation rules that span multiple arguments.
 * Supported constraint types:
 * - atLeastOne: At least one of the specified args must be provided
 * - exactlyOne: Exactly one of the specified args must be provided
 * - allOrNone: Either all or none of the specified args must be provided
 * ============================================================================ */

/**
 * Validates the constraints schema at decoration time.
 * Checks for:
 * - Valid constraint types
 * - Arg references exist in the args schema
 * - Constraint arrays have at least 2 elements
 * - Incompatible constraints (exactlyOne + allOrNone, exactlyOne + atLeastOne)
 * - Vacuous constraints (constraints rendered always true/false by defaults)
 *
 * @param {Object} constraints - The constraints object from decorator options.
 * @param {Object} argsSchema - The args schema object from decorator options.
 * @param {string} blockName - Block name for error messages.
 */
export function validateConstraintsSchema(constraints, argsSchema, blockName) {
  if (!constraints || typeof constraints !== "object") {
    return;
  }

  const declaredArgs = argsSchema ? Object.keys(argsSchema) : [];
  const constraintsByArgs = new Map();

  for (const [constraintType, argNames] of Object.entries(constraints)) {
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

    // Constraint value must be an array
    if (!Array.isArray(argNames)) {
      raiseBlockError(
        `Block "${blockName}": constraint "${constraintType}" must be an array of arg names.`
      );
      continue;
    }

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
    constraintsByArgs.get(sortedArgs).push(constraintType);

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
 * @param {string} constraintType - The constraint type.
 * @param {string[]} argNames - The arg names in the constraint.
 * @param {Object} argsSchema - The args schema.
 * @param {string} blockName - Block name for error messages.
 */
function checkVacuousConstraint(
  constraintType,
  argNames,
  argsSchema,
  blockName
) {
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
          `Block "${blockName}": constraint atLeastOne([${argNames.map((n) => `"${n}"`).join(", ")}]) ` +
            `is always true because "${argsWithDefaults[0]}" has a default value.`
        );
      }
      break;

    case "exactlyOne":
      // Always false if 2+ args have defaults (both will always be provided)
      if (argsWithDefaults.length >= 2) {
        raiseBlockError(
          `Block "${blockName}": constraint exactlyOne([${argNames.map((n) => `"${n}"`).join(", ")}]) ` +
            `is always false because multiple args have default values: ${argsWithDefaults.map((n) => `"${n}"`).join(", ")}.`
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
          `Block "${blockName}": constraint allOrNone([${argNames.map((n) => `"${n}"`).join(", ")}]) ` +
            `is always false because only some args have defaults: ${argsWithDefaults.map((n) => `"${n}"`).join(", ")} ` +
            `have defaults but ${argsWithoutDefaults.map((n) => `"${n}"`).join(", ")} do not.`
        );
      }
      // If all have defaults or none have defaults, constraint is not vacuous
      break;
  }
}

/**
 * Checks for incompatible constraint types on the same arg set.
 *
 * @param {string[]} constraintTypes - The constraint types applied to the same args.
 * @param {string} argSet - The sorted arg names (for error message).
 * @param {string} blockName - Block name for error messages.
 */
function checkIncompatibleConstraints(constraintTypes, argSet, blockName) {
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
}

/**
 * Validates constraints against the provided args at runtime.
 * Called after defaults are applied.
 *
 * @param {Object} constraints - The constraints from block metadata.
 * @param {Object} args - The resolved args (with defaults applied).
 * @param {string} blockName - Block name for error messages.
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
export function validateConstraints(constraints, args, blockName) {
  if (!constraints || typeof constraints !== "object") {
    return null;
  }

  for (const [constraintType, argNames] of Object.entries(constraints)) {
    if (!Array.isArray(argNames)) {
      continue;
    }

    let error = null;
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
 * @param {string[]} argNames - The arg names to check.
 * @param {Object} args - The resolved args.
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
function validateAtLeastOne(argNames, args) {
  const providedCount = argNames.filter(
    (name) => args[name] !== undefined
  ).length;

  if (providedCount === 0) {
    const argList = argNames.map((n) => `"${n}"`).join(", ");
    return `at least one of ${argList} must be provided.`;
  }

  return null;
}

/**
 * Validates that exactly one of the specified args is provided.
 *
 * @param {string[]} argNames - The arg names to check.
 * @param {Object} args - The resolved args.
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
function validateExactlyOne(argNames, args) {
  const providedArgs = argNames.filter((name) => args[name] !== undefined);
  const argList = argNames.map((n) => `"${n}"`).join(", ");

  if (providedArgs.length === 0) {
    return `exactly one of ${argList} must be provided, but got none.`;
  }

  if (providedArgs.length > 1) {
    const providedList = providedArgs.map((n) => `"${n}"`).join(", ");
    return `exactly one of ${argList} must be provided, but got ${providedArgs.length}: ${providedList}.`;
  }

  return null;
}

/**
 * Validates that either all or none of the specified args are provided.
 *
 * @param {string[]} argNames - The arg names to check.
 * @param {Object} args - The resolved args.
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
function validateAllOrNone(argNames, args) {
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
  const argList = argNames.map((n) => `"${n}"`).join(", ");

  return (
    `args ${argList} must be provided together or not at all. ` +
    `Got ${providedArgs.map((n) => `"${n}"`).join(", ")} but missing ${missingArgs.map((n) => `"${n}"`).join(", ")}.`
  );
}

/**
 * Runs a custom validation function if provided.
 *
 * @param {Function} validateFn - The custom validate function.
 * @param {Object} args - The resolved args (with defaults applied).
 * @returns {string[]|null} Array of error messages if validation fails, null otherwise.
 */
export function runCustomValidation(validateFn, args) {
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
    // Filter out non-string values and empty strings
    const errors = result.filter((e) => typeof e === "string" && e.length > 0);
    return errors.length > 0 ? errors : null;
  }

  // Invalid return type - ignore
  return null;
}
