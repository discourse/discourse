// @ts-check
/**
 * Shared arg validation utilities.
 *
 * This module provides generic validation functions for argument schemas
 * used by both blocks and conditions. Entity-specific validation logic
 * lives in separate modules:
 * - block-arg-validation.js - block-specific validation
 * - condition-arg-validation.js - condition-specific validation
 *
 * @module discourse/lib/blocks/arg-validation
 */

import { BlockError, raiseBlockError } from "discourse/lib/blocks/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Valid arg name pattern: must be a valid JavaScript identifier.
 * Starts with a letter, followed by letters, numbers, or underscores.
 * Note: Names starting with underscore are reserved for internal use.
 */
export const VALID_ARG_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9_]*$/;

/**
 * Valid arg types for schema definitions.
 */
export const VALID_ARG_TYPES = Object.freeze([
  "string",
  "number",
  "boolean",
  "array",
  "any",
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
  itemType: {
    allowedTypes: ["array"],
    // valueCheck handled separately (uses formatWithSuggestion for better error message)
    typeErrorSuffix: "array",
  },
  enum: {
    allowedTypes: ["string", "number"],
    // valueCheck handled separately (uses validateEnumArray)
    typeErrorSuffix: "string or number",
  },
  itemEnum: {
    allowedTypes: ["array"],
    // valueCheck handled separately (uses validateEnumArray)
    typeErrorSuffix: "array",
  },
});

/**
 * Validates a schema property against its rule.
 *
 * @param {string} prop - The property name.
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} entityName - The entity name for error messages.
 * @param {string} entityType - The entity type for error messages (e.g., "Block", "Condition").
 */
export function validateSchemaProperty(
  prop,
  argDef,
  argName,
  entityName,
  entityType
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

  // Check value validity (if valueCheck is defined)
  if (rule.valueCheck && !rule.valueCheck(argDef[prop])) {
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
 * @param {string} entityName - The entity name for error messages.
 * @param {string} minProp - The min property name.
 * @param {string} maxProp - The max property name.
 * @param {string} entityType - The entity type for error messages (e.g., "Block", "Condition").
 */
export function validateRangePair(
  argDef,
  argName,
  entityName,
  minProp,
  maxProp,
  entityType
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
 * Validates an enum-like array property (enum or itemEnum).
 * Checks that the value is a non-empty array and all items match the expected type.
 *
 * @param {Object} options - Validation options.
 * @param {*} options.enumValue - The enum array value to validate.
 * @param {string} options.propName - Property name ("enum" or "itemEnum").
 * @param {string|undefined} options.expectedType - Expected type for values, or undefined to skip type check.
 * @param {string} options.argName - The argument name for error messages.
 * @param {string} options.entityName - The entity name for error messages.
 * @param {string} options.entityType - The entity type.
 */
function validateEnumArray({
  enumValue,
  propName,
  expectedType,
  argName,
  entityName,
  entityType,
}) {
  if (!Array.isArray(enumValue) || enumValue.length === 0) {
    raiseBlockError(
      `${entityType} "${entityName}": arg "${argName}" has invalid "${propName}" value. Must be an array with at least one element.`
    );
    return;
  }

  if (expectedType !== undefined) {
    for (const value of enumValue) {
      if (typeof value !== expectedType) {
        raiseBlockError(
          `${entityType} "${entityName}": arg "${argName}" ${propName} contains invalid value "${value}". All values must be ${expectedType}s.`
        );
      }
    }
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
 * @param {string} entityName - The entity name for error messages.
 * @param {string} entityType - The entity type for error messages (e.g., "Block", "Condition").
 */
export function validateCommonSchemaProperties(
  argDef,
  argName,
  entityName,
  entityType
) {
  // Validate schema properties using declarative rules (type restrictions + value checks)
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

  // Validate itemType value (uses formatWithSuggestion for better error messages)
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

  // Validate enum array contents
  if (argDef.enum !== undefined) {
    const expectedType = argDef.type === "string" ? "string" : "number";
    validateEnumArray({
      enumValue: argDef.enum,
      propName: "enum",
      expectedType,
      argName,
      entityName,
      entityType,
    });
  }

  // Validate itemEnum array contents
  if (argDef.itemEnum !== undefined) {
    validateEnumArray({
      enumValue: argDef.itemEnum,
      propName: "itemEnum",
      expectedType: argDef.itemType, // undefined skips type check
      argName,
      entityName,
      entityType,
    });
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
 * @param {string} entityName - The entity name for error messages.
 * @param {string} entityType - The entity type for error messages (e.g., "Block", "Condition").
 * @param {string} [argLabel="arg"] - Label for error messages (e.g., "childArgs arg").
 * @returns {boolean} True if valid, false if invalid (and error raised).
 */
export function validateArgName(
  argName,
  entityName,
  entityType,
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
 * @param {string} entityName - The entity name for error messages.
 * @param {Object} options - Configuration options.
 * @param {string} options.entityType - The entity type for error messages (e.g., "Block", "Condition").
 * @param {readonly string[]} options.validProperties - List of valid schema properties.
 * @param {Object<string, string>} [options.disallowedProperties={}] - Map of property names to their
 *   specific error messages. Properties in this map trigger a "disallowed" error instead of "unknown".
 * @param {boolean} [options.allowAnyType=false] - If true, allow type: "any" (for conditions only).
 * @param {string} [options.argLabel="arg"] - Label for error messages (e.g., "childArgs arg").
 * @returns {boolean} True if validation should continue with caller-specific logic, false if
 *   validation should stop (e.g., missing type, type: "any" with allowAnyType).
 */
export function validateArgSchemaEntry(argDef, argName, entityName, options) {
  const {
    entityType,
    validProperties,
    disallowedProperties = {},
    allowAnyType = false,
    argLabel = "arg",
  } = options;

  // Check argDef is object
  if (!argDef || typeof argDef !== "object") {
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} "${argName}" must be an object with a "type" property.`
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

  // Type is required
  if (!argDef.type) {
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} "${argName}" is missing required "type" property.`
    );
    return false;
  }

  // Build valid types list based on whether "any" is allowed
  const validTypes = allowAnyType
    ? VALID_ARG_TYPES
    : VALID_ARG_TYPES.filter((t) => t !== "any");

  // Validate type
  if (!validTypes.includes(argDef.type)) {
    const suggestion = formatWithSuggestion(argDef.type, validTypes);
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} "${argName}" has invalid type ${suggestion}. ` +
        `Valid types are: ${validTypes.join(", ")}.`
    );
  }

  // "any" type skips further validation (enum, itemType checks don't apply)
  if (argDef.type === "any") {
    return false;
  }

  // Validate common schema properties
  validateCommonSchemaProperties(argDef, argName, entityName, entityType);

  return true;
}

/* Formatting Helpers */

/**
 * Formats an error message with optional context prefix.
 * Used to generate consistent error messages that vary based on context:
 * - Schema validation (at decoration time): includes entity context
 * - Runtime validation (in renderBlocks): no context prefix
 *
 * @param {string} argName - The argument name.
 * @param {string} message - The error message (without arg prefix).
 * @param {string|null} contextName - Optional entity name for context (e.g., block name).
 * @param {string} contextType - The entity type for the prefix (e.g., "Block", "Condition").
 * @returns {string} Formatted error message.
 */
export function formatArgError(argName, message, contextName, contextType) {
  return contextName
    ? `${contextType} "${contextName}": arg "${argName}" ${message}`
    : `Arg "${argName}" ${message}`;
}

/**
 * Validates a single argument value against its schema definition.
 *
 * @param {*} value - The argument value.
 * @param {Object} argSchema - The schema definition for this arg.
 * @param {string} argName - The argument name for error messages.
 * @param {string|null} [contextName=null] - Optional entity name for context.
 *   When provided, errors include context prefix.
 * @param {string|null} [contextType=null] - The entity type for error prefix (e.g., "Block", "Condition").
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
export function validateArgValue(
  value,
  argSchema,
  argName,
  contextName = null,
  contextType = null
) {
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
          contextName,
          contextType
        );
      }
      if (pattern && !pattern.test(value)) {
        return formatArgError(
          argName,
          `value "${value}" does not match required pattern ${pattern}.`,
          contextName,
          contextType
        );
      }
      if (minLength !== undefined && value.length < minLength) {
        return formatArgError(
          argName,
          `must be at least ${minLength} characters, got ${value.length}.`,
          contextName,
          contextType
        );
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return formatArgError(
          argName,
          `must be at most ${maxLength} characters, got ${value.length}.`,
          contextName,
          contextType
        );
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        const suggestion = formatWithSuggestion(value, enumValues);
        return formatArgError(
          argName,
          `must be one of: ${enumValues.map((v) => `"${v}"`).join(", ")}. Got ${suggestion}.`,
          contextName,
          contextType
        );
      }
      break;

    case "number":
      if (typeof value !== "number" || Number.isNaN(value)) {
        return formatArgError(
          argName,
          `must be a number, got ${typeof value}.`,
          contextName,
          contextType
        );
      }
      if (integer && !Number.isInteger(value)) {
        return formatArgError(
          argName,
          `must be an integer, got ${value}.`,
          contextName,
          contextType
        );
      }
      if (min !== undefined && value < min) {
        return formatArgError(
          argName,
          `must be at least ${min}, got ${value}.`,
          contextName,
          contextType
        );
      }
      if (max !== undefined && value > max) {
        return formatArgError(
          argName,
          `must be at most ${max}, got ${value}.`,
          contextName,
          contextType
        );
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return formatArgError(
          argName,
          `must be one of: ${enumValues.join(", ")}. Got ${value}.`,
          contextName,
          contextType
        );
      }
      break;

    case "boolean":
      if (typeof value !== "boolean") {
        return formatArgError(
          argName,
          `must be a boolean, got ${typeof value}.`,
          contextName,
          contextType
        );
      }
      break;

    case "array":
      if (!Array.isArray(value)) {
        return formatArgError(
          argName,
          `must be an array, got ${typeof value}.`,
          contextName,
          contextType
        );
      }
      if (minLength !== undefined && value.length < minLength) {
        return formatArgError(
          argName,
          `must have at least ${minLength} items, got ${value.length}.`,
          contextName,
          contextType
        );
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return formatArgError(
          argName,
          `must have at most ${maxLength} items, got ${value.length}.`,
          contextName,
          contextType
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
            contextName,
            contextType
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
              contextName,
              contextType
            );
          }
        }
      }
      break;

    case "any":
      // Any value is valid, no type checking needed
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
 * @param {string|null} [contextName=null] - Optional entity name for context.
 * @param {string|null} [contextType=null] - The entity type for error prefix (e.g., "Block", "Condition").
 * @returns {string|null} Error message if validation fails, null otherwise.
 */
export function validateArrayItemType(
  item,
  itemType,
  argName,
  index,
  contextName = null,
  contextType = null
) {
  const indexedArgName = `${argName}[${index}]`;

  switch (itemType) {
    case "string":
      if (typeof item !== "string") {
        return formatArgError(
          indexedArgName,
          `must be a string, got ${typeof item}.`,
          contextName,
          contextType
        );
      }
      break;

    case "number":
      if (typeof item !== "number" || Number.isNaN(item)) {
        return formatArgError(
          indexedArgName,
          `must be a number, got ${typeof item}.`,
          contextName,
          contextType
        );
      }
      break;

    case "boolean":
      if (typeof item !== "boolean") {
        return formatArgError(
          indexedArgName,
          `must be a boolean, got ${typeof item}.`,
          contextName,
          contextType
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
 * Validation order:
 * 1. Check for unknown args (catches typos before missing required)
 * 2. Check required args
 * 3. Validate type if value is provided
 *
 * The unknown args check is done FIRST so that typos like "nam" produce
 * "unknown arg 'nam' (did you mean 'name'?)" instead of "missing required arg 'name'".
 *
 * @param {Object} providedArgs - The arguments to validate.
 * @param {Object} schema - The schema to validate against.
 * @param {string} pathPrefix - Prefix for error paths (e.g., "args" or "containerArgs").
 * @throws {BlockError} If validation fails.
 */
export function validateArgsAgainstSchema(providedArgs, schema, pathPrefix) {
  // 1. Check for unknown args FIRST (catches typos before missing required)
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

  for (const [argName, argDef] of Object.entries(schema)) {
    const value = providedArgs[argName];

    // 2. Check required args
    if (argDef.required && value === undefined) {
      throw new BlockError(`missing required ${pathPrefix}.${argName}.`, {
        path: `${pathPrefix}.${argName}`,
      });
    }

    // 3. Validate type if value is provided
    if (value !== undefined) {
      const typeError = validateArgValue(value, argDef, argName);
      if (typeError) {
        throw new BlockError(typeError, { path: `${pathPrefix}.${argName}` });
      }
    }
  }
}
