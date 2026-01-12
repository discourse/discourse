import { BlockError, raiseBlockError } from "discourse/lib/blocks/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Valid arg name pattern: must be a valid JavaScript identifier.
 * Starts with a letter, followed by letters, numbers, or underscores.
 * Note: Names starting with underscore are reserved for internal use.
 */
export const VALID_ARG_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9_]*$/;

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
 * Valid properties for childArgs schema definitions.
 * Includes all standard arg properties plus "unique" for sibling uniqueness validation.
 */
export const VALID_CHILD_ARG_SCHEMA_PROPERTIES = Object.freeze([
  ...VALID_ARG_SCHEMA_PROPERTIES,
  "unique",
]);

/**
 * Schema property rules for declarative validation.
 * Each rule defines:
 * - allowedTypes: arg types that can use this property
 * - valueCheck: function to validate the property value
 * - valueError: error message if value check fails
 * - typeErrorSuffix: text to append for type restriction errors (e.g., "string or array")
 */
const SCHEMA_PROPERTY_RULES = Object.freeze({
  min: {
    allowedTypes: ["number"],
    valueCheck: (v) => typeof v === "number",
    valueError: "Must be a number.",
    typeErrorSuffix: "number",
  },
  max: {
    allowedTypes: ["number"],
    valueCheck: (v) => typeof v === "number",
    valueError: "Must be a number.",
    typeErrorSuffix: "number",
  },
  integer: {
    allowedTypes: ["number"],
    valueCheck: (v) => typeof v === "boolean",
    valueError: "Must be a boolean.",
    typeErrorSuffix: "number",
  },
  minLength: {
    allowedTypes: ["string", "array"],
    valueCheck: (v) => Number.isInteger(v) && v >= 0,
    valueError: "Must be a non-negative integer.",
    typeErrorSuffix: "string or array",
  },
  maxLength: {
    allowedTypes: ["string", "array"],
    valueCheck: (v) => Number.isInteger(v) && v >= 0,
    valueError: "Must be a non-negative integer.",
    typeErrorSuffix: "string or array",
  },
  pattern: {
    allowedTypes: ["string"],
    valueCheck: (v) => v instanceof RegExp,
    valueError: "Must be a RegExp.",
    typeErrorSuffix: "string",
  },
});

/**
 * Validates a schema property against its rule.
 *
 * @param {string} prop - The property name.
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} blockName - The block name.
 */
function validateSchemaProperty(prop, argDef, argName, blockName) {
  const rule = SCHEMA_PROPERTY_RULES[prop];
  if (!rule || argDef[prop] === undefined) {
    return;
  }

  // Check type restriction
  if (!rule.allowedTypes.includes(argDef.type)) {
    raiseBlockError(
      `Block "${blockName}": arg "${argName}" has "${prop}" but type is "${argDef.type}". ` +
        `"${prop}" is only valid for ${rule.typeErrorSuffix} type.`
    );
  }

  // Check value validity
  if (!rule.valueCheck(argDef[prop])) {
    raiseBlockError(
      `Block "${blockName}": arg "${argName}" has invalid "${prop}" value. ${rule.valueError}`
    );
  }
}

/**
 * Validates a min/max range pair in the schema.
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} blockName - The block name.
 * @param {string} minProp - The min property name.
 * @param {string} maxProp - The max property name.
 */
function validateRangePair(argDef, argName, blockName, minProp, maxProp) {
  if (
    argDef[minProp] !== undefined &&
    argDef[maxProp] !== undefined &&
    argDef[minProp] > argDef[maxProp]
  ) {
    raiseBlockError(
      `Block "${blockName}": arg "${argName}" has ${minProp} (${argDef[minProp]}) greater than ${maxProp} (${argDef[maxProp]}).`
    );
  }
}

/* Formatting Helpers */

/**
 * Formats an error message with optional block name prefix.
 * Used to generate consistent error messages that vary based on context:
 * - Schema validation (at decoration time): includes block name
 * - Runtime validation (in renderBlocks): no block name prefix
 *
 * @param {string} argName - The argument name.
 * @param {string} message - The error message (without arg prefix).
 * @param {string|null} blockName - Optional block name for context.
 * @returns {string} Formatted error message.
 */
function formatArgError(argName, message, blockName) {
  return blockName
    ? `Block "${blockName}": arg "${argName}" ${message}`
    : `Arg "${argName}" ${message}`;
}

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

    // Validate schema properties using declarative rules
    for (const prop of Object.keys(SCHEMA_PROPERTY_RULES)) {
      validateSchemaProperty(prop, argDef, argName, blockName);
    }

    // Validate range pairs
    validateRangePair(argDef, argName, blockName, "min", "max");
    validateRangePair(argDef, argName, blockName, "minLength", "maxLength");

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
 * @param {*} value - The argument value.
 * @param {Object} argSchema - The schema definition for this arg.
 * @param {string} argName - The argument name for error messages.
 * @param {string|null} [blockName=null] - Optional block name for context.
 *   When provided, errors include block name prefix.
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
export function validateArgValue(value, argSchema, argName, blockName = null) {
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
        return formatArgError(
          argName,
          `must be a string, got ${typeof value}.`,
          blockName
        );
      }
      if (pattern && !pattern.test(value)) {
        return formatArgError(
          argName,
          `value "${value}" does not match required pattern ${pattern}.`,
          blockName
        );
      }
      if (minLength !== undefined && value.length < minLength) {
        return formatArgError(
          argName,
          `must be at least ${minLength} characters, got ${value.length}.`,
          blockName
        );
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return formatArgError(
          argName,
          `must be at most ${maxLength} characters, got ${value.length}.`,
          blockName
        );
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return formatArgError(
          argName,
          `must be one of: ${enumValues.map((v) => `"${v}"`).join(", ")}. Got "${value}".`,
          blockName
        );
      }
      break;

    case "number":
      if (typeof value !== "number" || Number.isNaN(value)) {
        return formatArgError(
          argName,
          `must be a number, got ${typeof value}.`,
          blockName
        );
      }
      if (integer && !Number.isInteger(value)) {
        return formatArgError(
          argName,
          `must be an integer, got ${value}.`,
          blockName
        );
      }
      if (min !== undefined && value < min) {
        return formatArgError(
          argName,
          `must be at least ${min}, got ${value}.`,
          blockName
        );
      }
      if (max !== undefined && value > max) {
        return formatArgError(
          argName,
          `must be at most ${max}, got ${value}.`,
          blockName
        );
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return formatArgError(
          argName,
          `must be one of: ${enumValues.join(", ")}. Got ${value}.`,
          blockName
        );
      }
      break;

    case "boolean":
      if (typeof value !== "boolean") {
        return formatArgError(
          argName,
          `must be a boolean, got ${typeof value}.`,
          blockName
        );
      }
      break;

    case "array":
      if (!Array.isArray(value)) {
        return formatArgError(
          argName,
          `must be an array, got ${typeof value}.`,
          blockName
        );
      }
      if (minLength !== undefined && value.length < minLength) {
        return formatArgError(
          argName,
          `must have at least ${minLength} items, got ${value.length}.`,
          blockName
        );
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return formatArgError(
          argName,
          `must have at most ${maxLength} items, got ${value.length}.`,
          blockName
        );
      }
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
 * @param {*} item - The array item.
 * @param {string} itemType - The expected type ("string", "number", "boolean").
 * @param {string} argName - The argument name for error messages.
 * @param {string|null} [blockName=null] - Optional block name for context.
 * @param {number} index - The array index for error messages.
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
export function validateArrayItemType(
  item,
  itemType,
  argName,
  blockName = null,
  index
) {
  const indexedArgName = `${argName}[${index}]`;

  switch (itemType) {
    case "string":
      if (typeof item !== "string") {
        return formatArgError(
          indexedArgName,
          `must be a string, got ${typeof item}.`,
          blockName
        );
      }
      break;

    case "number":
      if (typeof item !== "number" || Number.isNaN(item)) {
        return formatArgError(
          indexedArgName,
          `must be a number, got ${typeof item}.`,
          blockName
        );
      }
      break;

    case "boolean":
      if (typeof item !== "boolean") {
        return formatArgError(
          indexedArgName,
          `must be a boolean, got ${typeof item}.`,
          blockName
        );
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
 * @throws {BlockError} If args are invalid.
 */
export function validateBlockArgs(config, blockClass) {
  const metadata = blockClass?.blockMetadata;
  const providedArgs = config.args || {};
  const hasProvidedArgs = Object.keys(providedArgs).length > 0;
  const argsSchema = metadata?.args;

  // If args are provided but no schema exists, reject them
  if (hasProvidedArgs && !argsSchema) {
    const argNames = Object.keys(providedArgs).join(", ");
    throw new BlockError(
      `args were provided (${argNames}) but this block does not declare an args schema. ` +
        `Add an args schema to the @block decorator or remove the args.`,
      { path: "args" }
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
      throw new BlockError(`missing required arg "${argName}".`, {
        path: `args.${argName}`,
      });
    }

    // Validate type if value is provided
    if (value !== undefined) {
      const typeError = validateArgValue(value, argDef, argName);
      if (typeError) {
        throw new BlockError(typeError, { path: `args.${argName}` });
      }
    }
  }

  // Check for unknown args (args provided but not in schema)
  const declaredArgs = Object.keys(argsSchema);
  for (const argName of Object.keys(providedArgs)) {
    if (!Object.hasOwn(argsSchema, argName)) {
      const suggestion = formatWithSuggestion(argName, declaredArgs);
      throw new BlockError(
        `unknown arg ${suggestion}. Declared args are: ${declaredArgs.join(", ") || "none"}.`,
        { path: `args.${argName}` }
      );
    }
  }
}

/**
 * Validates the childArgs schema definition passed to the @block decorator.
 * Similar to validateArgsSchema but supports the additional "unique" property
 * for enforcing uniqueness across sibling children.
 *
 * @param {Object} childArgsSchema - The childArgs schema object from decorator options.
 * @param {string} blockName - Block name for error messages.
 * @throws {Error} If schema is invalid.
 */
export function validateChildArgsSchema(childArgsSchema, blockName) {
  if (!childArgsSchema || typeof childArgsSchema !== "object") {
    return;
  }

  for (const [argName, argDef] of Object.entries(childArgsSchema)) {
    // Validate arg name format
    if (!VALID_ARG_NAME_PATTERN.test(argName)) {
      raiseBlockError(
        `Block "${blockName}": childArgs arg name "${argName}" is invalid. ` +
          `Arg names must start with a letter and contain only letters, numbers, and underscores.`
      );
      continue;
    }

    if (!argDef || typeof argDef !== "object") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" must be an object with a "type" property.`
      );
      continue;
    }

    // Check for unknown properties (including "unique" which is valid for childArgs)
    const unknownProps = Object.keys(argDef).filter(
      (prop) => !VALID_CHILD_ARG_SCHEMA_PROPERTIES.includes(prop)
    );
    if (unknownProps.length > 0) {
      const suggestions = unknownProps.map((prop) =>
        formatWithSuggestion(prop, VALID_CHILD_ARG_SCHEMA_PROPERTIES)
      );
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has unknown properties: ${suggestions.join(", ")}. ` +
          `Valid properties are: ${VALID_CHILD_ARG_SCHEMA_PROPERTIES.join(", ")}.`
      );
    }

    // Validate "unique" is a boolean if provided
    if (argDef.unique !== undefined && typeof argDef.unique !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has invalid "unique" value. Must be a boolean.`
      );
    }

    // Validate "unique" is only used with primitive types (not arrays)
    if (argDef.unique === true && argDef.type === "array") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has "unique: true" but type is "array". ` +
          `Uniqueness validation is only supported for primitive types (string, number, boolean).`
      );
    }

    // Type is required
    if (!argDef.type) {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" is missing required "type" property.`
      );
      continue;
    }

    // Validate type
    if (!VALID_ARG_TYPES.includes(argDef.type)) {
      const suggestion = formatWithSuggestion(argDef.type, VALID_ARG_TYPES);
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has invalid type ${suggestion}. ` +
          `Valid types are: ${VALID_ARG_TYPES.join(", ")}.`
      );
    }

    // itemType is only valid for array type
    if (argDef.itemType !== undefined && argDef.type !== "array") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has "itemType" but type is "${argDef.type}". ` +
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
          `Block "${blockName}": childArgs arg "${argName}" has invalid itemType ${suggestion}. ` +
            `Valid item types are: ${VALID_ITEM_TYPES.join(", ")}.`
        );
      }
    }

    // Validate schema properties using declarative rules
    for (const prop of Object.keys(SCHEMA_PROPERTY_RULES)) {
      validateSchemaProperty(prop, argDef, argName, blockName);
    }

    // Validate range pairs
    validateRangePair(argDef, argName, blockName, "min", "max");
    validateRangePair(argDef, argName, blockName, "minLength", "maxLength");

    // enum is only valid for string or number type
    if (
      argDef.enum !== undefined &&
      argDef.type !== "string" &&
      argDef.type !== "number"
    ) {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has "enum" but type is "${argDef.type}". ` +
          `"enum" is only valid for string or number type.`
      );
    }

    // Validate enum is an array with at least one element
    if (argDef.enum !== undefined) {
      if (!Array.isArray(argDef.enum) || argDef.enum.length === 0) {
        raiseBlockError(
          `Block "${blockName}": childArgs arg "${argName}" has invalid "enum" value. Must be an array with at least one element.`
        );
      } else {
        // Validate all enum values match the arg type
        const expectedType = argDef.type === "string" ? "string" : "number";
        for (const enumValue of argDef.enum) {
          if (typeof enumValue !== expectedType) {
            raiseBlockError(
              `Block "${blockName}": childArgs arg "${argName}" enum contains invalid value "${enumValue}". All values must be ${expectedType}s.`
            );
          }
        }
      }
    }

    // Validate required is boolean
    if (argDef.required !== undefined && typeof argDef.required !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has invalid "required" value. Must be a boolean.`
      );
    }

    // required + default is contradictory - default makes required meaningless
    if (argDef.required === true && argDef.default !== undefined) {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has both "required: true" and "default". ` +
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
          `Block "${blockName}": childArgs arg "${argName}" has invalid default value. ${defaultError}`
        );
      }
    }
  }
}
