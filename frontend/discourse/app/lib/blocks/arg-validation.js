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

    // Validate required is boolean
    if (argDef.required !== undefined && typeof argDef.required !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid "required" value. Must be a boolean.`
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
  const { type, itemType, pattern } = argSchema;

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
      break;

    case "number":
      if (typeof value !== "number" || Number.isNaN(value)) {
        return `Block "${blockName}": arg "${argName}" must be a number, got ${typeof value}.`;
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

  // No metadata or no args schema means nothing to validate
  if (!metadata?.args) {
    return;
  }

  const argsSchema = metadata.args;
  const providedArgs = config.args || {};

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
  const { type, itemType, pattern } = argSchema;

  switch (type) {
    case "string":
      if (typeof value !== "string") {
        return `Arg "${argName}" must be a string, got ${typeof value}.`;
      }
      if (pattern && !pattern.test(value)) {
        return `Arg "${argName}" value "${value}" does not match required pattern ${pattern}.`;
      }
      break;

    case "number":
      if (typeof value !== "number" || Number.isNaN(value)) {
        return `Arg "${argName}" must be a number, got ${typeof value}.`;
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
