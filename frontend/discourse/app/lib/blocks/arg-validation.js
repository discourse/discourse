import { raiseBlockError } from "discourse/lib/blocks/error";

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
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has unknown properties: ${unknownProps.join(", ")}. ` +
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
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has invalid type "${argDef.type}". ` +
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
        raiseBlockError(
          `Block "${blockName}": arg "${argName}" has invalid itemType "${argDef.itemType}". ` +
            `Valid item types are: ${VALID_ITEM_TYPES.join(", ")}.`
        );
      }
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
  const { type, itemType } = argSchema;

  // Skip validation if value is undefined (handled by required check)
  if (value === undefined) {
    return null;
  }

  switch (type) {
    case "string":
      if (typeof value !== "string") {
        return `Block "${blockName}": arg "${argName}" must be a string, got ${typeof value}.`;
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
 * @param {Object} config - The block configuration
 * @param {string} outletName - The outlet name for error messages
 */
export function validateBlockArgs(config, outletName) {
  const blockClass = config.block;
  const blockName = blockClass?.blockName || "unknown";
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
      raiseBlockError(
        `Block "${blockName}" in outlet "${outletName}" is missing required arg "${argName}".`
      );
      continue;
    }

    // Validate type if value is provided
    if (value !== undefined) {
      const typeError = validateArgValue(value, argDef, argName, blockName);
      if (typeError) {
        raiseBlockError(typeError);
      }
    }
  }

  // Check for unknown args (args provided but not in schema)
  for (const argName of Object.keys(providedArgs)) {
    if (!Object.hasOwn(argsSchema, argName)) {
      raiseBlockError(
        `Block "${blockName}" in outlet "${outletName}" received unknown arg "${argName}". ` +
          `Declared args are: ${Object.keys(argsSchema).join(", ") || "none"}.`
      );
    }
  }
}
