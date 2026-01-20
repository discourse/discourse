// @ts-check
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
  "itemEnum",
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
export const SCHEMA_PROPERTY_RULES = Object.freeze({
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
 * @param {string} entityName - The entity name (block or condition name).
 * @param {string} [entityType="Block"] - The entity type ("Block" or "Condition").
 */
export function validateSchemaProperty(
  prop,
  argDef,
  argName,
  entityName,
  entityType = "Block"
) {
  const rule = SCHEMA_PROPERTY_RULES[prop];
  if (!rule || argDef[prop] === undefined) {
    return;
  }

  // Check type restriction
  if (!rule.allowedTypes.includes(argDef.type)) {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has "${prop}" but type is "${argDef.type}". ` +
        `"${prop}" is only valid for ${rule.typeErrorSuffix} type.`
    );
  }

  // Check value validity
  if (!rule.valueCheck(argDef[prop])) {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has invalid "${prop}" value. ${rule.valueError}`
    );
  }
}

/**
 * Validates a min/max range pair in the schema.
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} entityName - The entity name (block or condition name).
 * @param {string} minProp - The min property name.
 * @param {string} maxProp - The max property name.
 * @param {string} [entityType="Block"] - The entity type ("Block" or "Condition").
 */
export function validateRangePair(
  argDef,
  argName,
  entityName,
  minProp,
  maxProp,
  entityType = "Block"
) {
  if (
    argDef[minProp] !== undefined &&
    argDef[maxProp] !== undefined &&
    argDef[minProp] > argDef[maxProp]
  ) {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has ${minProp} (${argDef[minProp]}) greater than ${maxProp} (${argDef[maxProp]}).`
    );
  }
}

/**
 * Validates the common schema properties that are shared between blocks and conditions.
 * This includes itemType, schema property rules, range pairs, enum, itemEnum, and required.
 *
 * Does NOT validate:
 * - "type is required" - blocks require it, conditions allow empty schemas for "any type"
 * - "default" validation - blocks validate default values, conditions reject the property entirely
 * - "required + default contradiction" - only relevant for blocks
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} entityName - The entity name (block or condition name).
 * @param {string} [entityType="Block"] - The entity type ("Block" or "Condition").
 */
export function validateCommonSchemaProperties(
  argDef,
  argName,
  entityName,
  entityType = "Block"
) {
  // itemType is only valid for array type
  if (argDef.itemType !== undefined && argDef.type !== "array") {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has "itemType" but type is "${argDef.type}". ` +
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
        `${entityType} "${entityName}": arg "${argName}" has invalid itemType ${suggestion}. ` +
          `Valid item types are: ${VALID_ITEM_TYPES.join(", ")}.`
      );
    }
  }

  // Validate schema properties using declarative rules
  for (const prop of Object.keys(SCHEMA_PROPERTY_RULES)) {
    validateSchemaProperty(prop, argDef, argName, entityName, entityType);
  }

  // Validate range pairs
  validateRangePair(argDef, argName, entityName, "min", "max", entityType);
  validateRangePair(
    argDef,
    argName,
    entityName,
    "minLength",
    "maxLength",
    entityType
  );

  // enum is only valid for string or number type
  if (
    argDef.enum !== undefined &&
    argDef.type !== "string" &&
    argDef.type !== "number"
  ) {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has "enum" but type is "${argDef.type}". ` +
        `"enum" is only valid for string or number type.`
    );
  }

  // Validate enum is an array with at least one element
  if (argDef.enum !== undefined) {
    if (!Array.isArray(argDef.enum) || argDef.enum.length === 0) {
      raiseBlockError(
        `${entityType} "${entityName}": arg "${argName}" has invalid "enum" value. Must be an array with at least one element.`
      );
    } else {
      // Validate all enum values match the arg type
      const expectedType = argDef.type === "string" ? "string" : "number";
      for (const enumValue of argDef.enum) {
        if (typeof enumValue !== expectedType) {
          raiseBlockError(
            `${entityType} "${entityName}": arg "${argName}" enum contains invalid value "${enumValue}". All values must be ${expectedType}s.`
          );
        }
      }
    }
  }

  // itemEnum is only valid for array type
  if (argDef.itemEnum !== undefined && argDef.type !== "array") {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has "itemEnum" but type is "${argDef.type}". ` +
        `"itemEnum" is only valid for array type.`
    );
  }

  // Validate itemEnum is an array with at least one element
  if (argDef.itemEnum !== undefined) {
    if (!Array.isArray(argDef.itemEnum) || argDef.itemEnum.length === 0) {
      raiseBlockError(
        `${entityType} "${entityName}": arg "${argName}" has invalid "itemEnum" value. Must be an array with at least one element.`
      );
    } else if (argDef.itemType !== undefined) {
      // Validate all itemEnum values match the itemType
      for (const enumValue of argDef.itemEnum) {
        if (typeof enumValue !== argDef.itemType) {
          raiseBlockError(
            `${entityType} "${entityName}": arg "${argName}" itemEnum contains invalid value "${enumValue}". All values must be ${argDef.itemType}s.`
          );
        }
      }
    }
  }

  // Validate required is boolean
  if (argDef.required !== undefined && typeof argDef.required !== "boolean") {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has invalid "required" value. Must be a boolean.`
    );
  }
}

/* Arg Schema Entry Validation Helpers */

/**
 * Validates an argument name format.
 *
 * @param {string} argName - The argument name to validate.
 * @param {string} entityName - The entity name (block or condition name).
 * @param {string} [entityType="Block"] - The entity type ("Block" or "Condition").
 * @param {string} [argLabel="arg"] - Label for error messages (e.g., "childArgs arg").
 * @returns {boolean} True if valid, false if invalid (and error raised).
 */
export function validateArgName(
  argName,
  entityName,
  entityType = "Block",
  argLabel = "arg"
) {
  if (!VALID_ARG_NAME_PATTERN.test(argName)) {
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} name "${argName}" is invalid. ` +
        `Arg names must start with a letter and contain only letters, numbers, and underscores.`
    );
    return false;
  }
  return true;
}

/**
 * Validates a single arg schema entry (argDef).
 * Shared logic between block args, childArgs, and condition args validation.
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} entityName - The entity name (block or condition name).
 * @param {Object} options - Configuration options.
 * @param {string} [options.entityType="Block"] - "Block" or "Condition".
 * @param {readonly string[]} options.validProperties - List of valid schema properties.
 * @param {Object<string, string>} [options.disallowedProperties={}] - Map of property names to their
 *   specific error messages. Properties in this map trigger a "disallowed" error instead of "unknown".
 * @param {boolean} [options.allowEmptySchema=false] - If true, skip validation for empty {}.
 * @param {string} [options.argLabel="arg"] - Label for error messages (e.g., "childArgs arg").
 * @returns {boolean} True if validation should continue with caller-specific logic, false if
 *   validation should stop (e.g., missing type, empty schema with allowEmptySchema).
 */
export function validateArgSchemaEntry(argDef, argName, entityName, options) {
  const {
    entityType = "Block",
    validProperties,
    disallowedProperties = {},
    allowEmptySchema = false,
    argLabel = "arg",
  } = options;

  // Check argDef is object
  if (!argDef || typeof argDef !== "object") {
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} "${argName}" must be an object${entityType === "Block" ? ' with a "type" property' : ""}.`
    );
    return false;
  }

  // Check for unknown/disallowed properties
  const disallowedPropNames = Object.keys(disallowedProperties);
  const unknownProps = Object.keys(argDef).filter(
    (prop) => !validProperties.includes(prop)
  );
  if (unknownProps.length > 0) {
    const disallowed = unknownProps.filter((p) =>
      disallowedPropNames.includes(p)
    );
    if (disallowed.length > 0) {
      const prop = disallowed[0];
      raiseBlockError(
        `${entityType} "${entityName}": ${argLabel} "${argName}" has disallowed property "${prop}". ` +
          disallowedProperties[prop]
      );
    } else {
      const suggestions = unknownProps.map((prop) =>
        formatWithSuggestion(prop, validProperties)
      );
      raiseBlockError(
        `${entityType} "${entityName}": ${argLabel} "${argName}" has unknown properties: ${suggestions.join(", ")}. ` +
          `Valid properties are: ${validProperties.join(", ")}.`
      );
    }
  }

  // Empty schema handling (for conditions: allows "any type")
  if (allowEmptySchema && Object.keys(argDef).length === 0) {
    return false;
  }

  // Type is required
  if (!argDef.type) {
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} "${argName}" is missing required "type" property.`
    );
    return false;
  }

  // Validate type
  if (!VALID_ARG_TYPES.includes(argDef.type)) {
    const suggestion = formatWithSuggestion(argDef.type, VALID_ARG_TYPES);
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} "${argName}" has invalid type ${suggestion}. ` +
        `Valid types are: ${VALID_ARG_TYPES.join(", ")}.`
    );
  }

  // Validate common schema properties
  validateCommonSchemaProperties(argDef, argName, entityName, entityType);

  return true;
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
    if (!validateArgName(argName, blockName)) {
      continue;
    }

    const shouldContinue = validateArgSchemaEntry(argDef, argName, blockName, {
      validProperties: VALID_ARG_SCHEMA_PROPERTIES,
    });

    if (!shouldContinue) {
      continue;
    }

    // Block-specific: required + default is contradictory
    if (argDef.required === true && argDef.default !== undefined) {
      raiseBlockError(
        `Block "${blockName}": arg "${argName}" has both "required: true" and "default". ` +
          `These options are contradictory - an arg with a default value is never missing.`
      );
    }

    // Block-specific: validate default value matches type
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
    itemEnum,
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
        const suggestion = formatWithSuggestion(value, enumValues);
        return formatArgError(
          argName,
          `must be one of: ${enumValues.map((v) => `"${v}"`).join(", ")}. Got ${suggestion}.`,
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
            i,
            blockName
          );
          if (itemError) {
            return itemError;
          }
        }
      }
      if (itemEnum !== undefined) {
        for (let i = 0; i < value.length; i++) {
          const item = value[i];
          if (!itemEnum.includes(item)) {
            const suggestion = formatWithSuggestion(
              String(item),
              itemEnum.map(String)
            );
            const indexedArgName = `${argName}[${i}]`;
            return formatArgError(
              indexedArgName,
              `must be one of: ${itemEnum.map((v) => `"${v}"`).join(", ")}. Got ${suggestion}.`,
              blockName
            );
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
 * @param {number} index - The array index for error messages.
 * @param {string|null} [blockName=null] - Optional block name for context.
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
export function validateArrayItemType(
  item,
  itemType,
  argName,
  index,
  blockName = null
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
 * Validates provided arguments against a schema.
 * This is the core validation logic used by both block args and container args validation.
 *
 * @param {Object} providedArgs - The arguments to validate.
 * @param {Object} schema - The schema to validate against.
 * @param {string} pathPrefix - Prefix for error paths (e.g., "args" or "containerArgs").
 * @throws {BlockError} If validation fails.
 */
export function validateArgsAgainstSchema(providedArgs, schema, pathPrefix) {
  for (const [argName, argDef] of Object.entries(schema)) {
    const value = providedArgs[argName];

    // Check required args
    if (argDef.required && value === undefined) {
      throw new BlockError(`missing required ${pathPrefix}.${argName}.`, {
        path: `${pathPrefix}.${argName}`,
      });
    }

    // Validate type if value is provided
    if (value !== undefined) {
      const typeError = validateArgValue(value, argDef, argName);
      if (typeError) {
        throw new BlockError(typeError, { path: `${pathPrefix}.${argName}` });
      }
    }
  }

  // Check for unknown args (args provided but not in schema)
  const declaredArgs = Object.keys(schema);
  for (const argName of Object.keys(providedArgs)) {
    if (!Object.hasOwn(schema, argName)) {
      const suggestion = formatWithSuggestion(argName, declaredArgs);
      throw new BlockError(
        `unknown ${pathPrefix} ${suggestion}. Declared args are: ${declaredArgs.join(", ") || "none"}.`,
        { path: `${pathPrefix}.${argName}` }
      );
    }
  }
}

/**
 * Validates block arguments against the block's metadata arg schema.
 * Checks for required args and validates types.
 *
 * @param {Object} entry - The block entry.
 * @param {Object} blockClass - The resolved block class (must be a class, not a string reference).
 * @throws {BlockError} If args are invalid.
 */
export function validateBlockArgs(entry, blockClass) {
  const metadata = blockClass?.blockMetadata;
  const providedArgs = entry.args || {};
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

  validateArgsAgainstSchema(providedArgs, argsSchema, "args");
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
    if (!validateArgName(argName, blockName, "Block", "childArgs arg")) {
      continue;
    }

    const shouldContinue = validateArgSchemaEntry(argDef, argName, blockName, {
      validProperties: VALID_CHILD_ARG_SCHEMA_PROPERTIES,
      argLabel: "childArgs arg",
    });

    if (!shouldContinue) {
      continue;
    }

    // childArgs-specific: validate "unique" is a boolean if provided
    if (argDef.unique !== undefined && typeof argDef.unique !== "boolean") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has invalid "unique" value. Must be a boolean.`
      );
    }

    // childArgs-specific: validate "unique" is only used with primitive types
    if (argDef.unique === true && argDef.type === "array") {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has "unique: true" but type is "array". ` +
          `Uniqueness validation is only supported for primitive types (string, number, boolean).`
      );
    }

    // Block-specific: required + default contradiction
    if (argDef.required === true && argDef.default !== undefined) {
      raiseBlockError(
        `Block "${blockName}": childArgs arg "${argName}" has both "required: true" and "default". ` +
          `These options are contradictory - an arg with a default value is never missing.`
      );
    }

    // Block-specific: validate default value matches type
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
