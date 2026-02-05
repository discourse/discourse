// @ts-check
/**
 * Shared arg validation utilities.
 *
 * This module provides generic validation functions for argument schemas
 * used by both blocks and conditions. Entity-specific validation logic
 * lives in separate modules:
 * - block-args.js - block-specific validation
 * - condition-args.js - condition-specific validation
 *
 * @module discourse/lib/blocks/-internals/validation/args
 */

import {
  BlockError,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";
import RestModel from "discourse/models/rest";

/**
 * A validation error result containing the error message and the path
 * to the argument that failed validation.
 *
 * @typedef {Object} ValidationError
 * @property {string} message - The formatted error message.
 * @property {string} path - The path to the invalid argument (e.g., "test.name").
 */

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
  "object",
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
  "properties",
  "instanceOf",
  "instanceOfName",
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
  properties: {
    allowedTypes: ["object"],
    // valueCheck handled separately (recursive schema validation)
    typeErrorSuffix: "object",
  },
  instanceOf: {
    allowedTypes: ["object"],
    // valueCheck handled separately (function or "model:*" string)
    typeErrorSuffix: "object",
  },
});

/**
 * Validates a schema property against its rule.
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} prop - The property name.
 * @param {Object} [options] - Optional configuration.
 * @param {string} [options.entityName] - The entity name for error messages.
 * @param {string} [options.entityType="Block"] - The entity type for error messages.
 */
export function validateSchemaProperty(argDef, argName, prop, options = {}) {
  const { entityName, entityType = "Block" } = options;

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
 * Validates that at most one of the specified schema properties is defined (mutually exclusive).
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name for error messages.
 * @param {string[]} properties - Array of property names that are mutually exclusive.
 * @param {Object} [options] - Optional configuration.
 * @param {string} [options.entityName] - The entity name for error messages.
 * @param {string} [options.entityType="Block"] - The entity type (e.g., "Block", "Condition").
 * @param {string} [options.argLabel="arg"] - Label for the argument (e.g., "arg", "childArgs arg").
 * @param {string} [options.reason] - Custom reason message.
 */
export function validateMutuallyExclusive(
  argDef,
  argName,
  properties,
  options = {}
) {
  const {
    entityName,
    entityType = "Block",
    argLabel = "arg",
    reason = "These are mutually exclusive - use only one.",
  } = options;

  const definedProps = properties.filter((prop) => argDef[prop] !== undefined);

  if (definedProps.length > 1) {
    // Format the list of conflicting properties
    const propList =
      definedProps.length === 2
        ? `"${definedProps[0]}" and "${definedProps[1]}"`
        : definedProps.map((p) => `"${p}"`).join(", ");

    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} "${argName}" has ${propList}. ${reason}`
    );
  }
}

/**
 * Validates a min/max range pair in the schema.
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} minProp - The min property name.
 * @param {string} maxProp - The max property name.
 * @param {Object} [options] - Optional configuration.
 * @param {string} [options.entityName] - The entity name for error messages.
 * @param {string} [options.entityType="Block"] - The entity type for error messages.
 */
export function validateRangePair(
  argDef,
  argName,
  minProp,
  maxProp,
  options = {}
) {
  const { entityName, entityType = "Block" } = options;

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
 * @param {Object} [options] - Optional configuration.
 * @param {string} [options.entityName] - The entity name for error messages.
 * @param {string} [options.entityType="Block"] - The entity type for error messages.
 */
export function validateCommonSchemaProperties(argDef, argName, options = {}) {
  const { entityName, entityType = "Block" } = options;
  const context = { entityName, entityType };

  // Validate schema properties using declarative rules (type restrictions + value checks)
  for (const prop of Object.keys(SCHEMA_PROPERTY_RULES)) {
    validateSchemaProperty(argDef, argName, prop, context);
  }

  // Validate range pairs
  validateRangePair(argDef, argName, "min", "max", context);
  validateRangePair(argDef, argName, "minLength", "maxLength", context);

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

  // Validate properties schema for object types
  if (argDef.type === "object" && argDef.properties !== undefined) {
    if (
      !argDef.properties ||
      typeof argDef.properties !== "object" ||
      Array.isArray(argDef.properties)
    ) {
      raiseBlockError(
        `${entityType} "${entityName}": arg "${argName}" has invalid "properties" value. Must be an object.`
      );
    } else {
      // Recursively validate each property schema
      for (const [propName, propDef] of Object.entries(argDef.properties)) {
        validateArgName(propName, {
          ...context,
          argLabel: `arg "${argName}" property`,
        });

        // Validate the property definition recursively
        const nestedArgName = `${argName}.properties.${propName}`;
        validateArgSchemaEntry(propDef, nestedArgName, {
          ...context,
          validProperties: VALID_ARG_SCHEMA_PROPERTIES,
          allowAnyType: false,
          argLabel: "property",
        });
      }
    }
  }

  // Validate instanceOf for object types
  if (argDef.type === "object" && argDef.instanceOf !== undefined) {
    // Check mutual exclusivity with properties
    validateMutuallyExclusive(
      argDef,
      argName,
      ["instanceOf", "properties"],
      context
    );

    // Validate instanceOf value: must be a function (constructor) or "model:*" string
    const isFunction = typeof argDef.instanceOf === "function";
    const isModelString =
      typeof argDef.instanceOf === "string" &&
      argDef.instanceOf.startsWith("model:");

    if (!isFunction && !isModelString) {
      raiseBlockError(
        `${entityType} "${entityName}": arg "${argName}" has invalid "instanceOf" value. ` +
          `Must be a class constructor or a "model:*" string (e.g., "model:user").`
      );
    }
  }

  // Validate instanceOfName for object types (only valid when instanceOf is a class reference)
  if (argDef.instanceOfName !== undefined) {
    if (argDef.instanceOf === undefined) {
      raiseBlockError(
        `${entityType} "${entityName}": arg "${argName}" has "instanceOfName" but no "instanceOf". ` +
          `"instanceOfName" is only valid when "instanceOf" is also specified.`
      );
    }
    if (typeof argDef.instanceOf === "string") {
      raiseBlockError(
        `${entityType} "${entityName}": arg "${argName}" has "instanceOfName" with a "model:*" instanceOf. ` +
          `"instanceOfName" is only valid for class references, not model strings.`
      );
    }
    if (typeof argDef.instanceOfName !== "string") {
      raiseBlockError(
        `${entityType} "${entityName}": arg "${argName}" has invalid "instanceOfName" value. ` +
          `Must be a string.`
      );
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
 * @param {Object} [options] - Optional configuration.
 * @param {string} [options.entityName] - The entity name for error messages.
 * @param {string} [options.entityType="Block"] - The entity type for error messages.
 * @param {string} [options.argLabel="arg"] - Label for error messages (e.g., "childArgs arg").
 * @returns {boolean} True if valid, false if invalid (and error raised).
 */
export function validateArgName(argName, options = {}) {
  const { entityName, entityType = "Block", argLabel = "arg" } = options;

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
 * @param {Object} options - Configuration options.
 * @param {string} [options.entityName] - The entity name for error messages.
 * @param {string} [options.entityType="Block"] - The entity type for error messages.
 * @param {readonly string[]} options.validProperties - List of valid schema properties.
 * @param {Object<string, string>} [options.disallowedProperties={}] - Map of property names to their
 *   specific error messages. Properties in this map trigger a "disallowed" error instead of "unknown".
 * @param {boolean} [options.allowAnyType=false] - If true, allow type: "any" (for conditions only).
 * @param {string} [options.argLabel="arg"] - Label for error messages (e.g., "childArgs arg").
 * @returns {boolean} True if validation should continue with caller-specific logic, false if
 *   validation should stop (e.g., missing type, type: "any" with allowAnyType).
 */
export function validateArgSchemaEntry(argDef, argName, options) {
  const {
    entityName,
    entityType = "Block",
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
  validateCommonSchemaProperties(argDef, argName, { entityName, entityType });

  return true;
}

/* Formatting Helpers */

/**
 * Creates a validation error with a formatted message and path.
 * Used to generate consistent error objects that vary based on context:
 * - Schema validation (at decoration time): includes entity context
 * - Runtime validation (in renderBlocks): no context prefix
 *
 * @param {string} argName - The argument name (used as the path).
 * @param {string} message - The error message (without arg prefix).
 * @param {Object} [options] - Optional configuration.
 * @param {string|null} [options.contextName] - Optional entity name for context (e.g., block name).
 * @param {string} [options.contextType] - The entity type for the prefix (e.g., "Block", "Condition").
 * @returns {ValidationError} The validation error object with message and path.
 */
function argValidationError(argName, message, options = {}) {
  const { contextName, contextType } = options;
  const formattedMessage = contextName
    ? `${contextType} "${contextName}": arg "${argName}" ${message}`
    : `Arg "${argName}" ${message}`;
  return { message: formattedMessage, path: argName };
}

/**
 * Validates a single argument value against its schema definition.
 *
 * @param {*} value - The argument value.
 * @param {Object} argSchema - The schema definition for this arg.
 * @param {string} argName - The argument name for error messages.
 * @param {Object} [options] - Optional configuration.
 * @param {string|null} [options.contextName] - Optional entity name for context.
 * @param {string} [options.contextType] - The entity type for error prefix (e.g., "Block", "Condition").
 * @param {Object} [options.owner] - Ember owner for registry lookups (used for "model:*" instanceOf).
 * @returns {ValidationError|null} Validation error if validation fails, null otherwise.
 */
export function validateArgValue(value, argSchema, argName, options = {}) {
  const { owner } = options;

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
    instanceOf,
  } = argSchema;

  // Skip validation if value is undefined (handled by required check)
  if (value === undefined) {
    return null;
  }

  switch (type) {
    case "string":
      if (typeof value !== "string") {
        return argValidationError(
          argName,
          `must be a string, got ${typeof value}.`,
          options
        );
      }
      if (pattern && !pattern.test(value)) {
        return argValidationError(
          argName,
          `value "${value}" does not match required pattern ${pattern}.`,
          options
        );
      }
      if (minLength !== undefined && value.length < minLength) {
        return argValidationError(
          argName,
          `must be at least ${minLength} characters, got ${value.length}.`,
          options
        );
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return argValidationError(
          argName,
          `must be at most ${maxLength} characters, got ${value.length}.`,
          options
        );
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        const suggestion = formatWithSuggestion(value, enumValues);
        return argValidationError(
          argName,
          `must be one of: ${enumValues.map((v) => `"${v}"`).join(", ")}. Got ${suggestion}.`,
          options
        );
      }
      break;

    case "number":
      if (typeof value !== "number" || Number.isNaN(value)) {
        return argValidationError(
          argName,
          `must be a number, got ${typeof value}.`,
          options
        );
      }
      if (integer && !Number.isInteger(value)) {
        return argValidationError(
          argName,
          `must be an integer, got ${value}.`,
          options
        );
      }
      if (min !== undefined && value < min) {
        return argValidationError(
          argName,
          `must be at least ${min}, got ${value}.`,
          options
        );
      }
      if (max !== undefined && value > max) {
        return argValidationError(
          argName,
          `must be at most ${max}, got ${value}.`,
          options
        );
      }
      if (enumValues !== undefined && !enumValues.includes(value)) {
        return argValidationError(
          argName,
          `must be one of: ${enumValues.join(", ")}. Got ${value}.`,
          options
        );
      }
      break;

    case "boolean":
      if (typeof value !== "boolean") {
        return argValidationError(
          argName,
          `must be a boolean, got ${typeof value}.`,
          options
        );
      }
      break;

    case "array":
      if (!Array.isArray(value)) {
        return argValidationError(
          argName,
          `must be an array, got ${typeof value}.`,
          options
        );
      }
      if (minLength !== undefined && value.length < minLength) {
        return argValidationError(
          argName,
          `must have at least ${minLength} items, got ${value.length}.`,
          options
        );
      }
      if (maxLength !== undefined && value.length > maxLength) {
        return argValidationError(
          argName,
          `must have at most ${maxLength} items, got ${value.length}.`,
          options
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
            options
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
            return argValidationError(
              indexedArgName,
              `must be one of: ${itemEnum.map((v) => `"${v}"`).join(", ")}. Got ${suggestion}.`,
              options
            );
          }
        }
      }
      break;

    case "object": {
      // Check for plain object (not array, null, or other types)
      // Note: For instanceOf validation, we allow non-plain objects (class instances)
      if (!instanceOf) {
        if (
          value === null ||
          typeof value !== "object" ||
          Array.isArray(value)
        ) {
          let actualType;
          if (value === null) {
            actualType = "null";
          } else if (Array.isArray(value)) {
            actualType = "array";
          } else {
            actualType = typeof value;
          }
          return argValidationError(
            argName,
            `must be an object, got ${actualType}.`,
            options
          );
        }
      }

      // Validate instanceOf if specified
      if (instanceOf) {
        if (typeof instanceOf === "function") {
          // Direct class reference
          if (!(value instanceof instanceOf)) {
            // Use instanceOfName if provided, otherwise fall back to generic message.
            // The generic fallback handles two edge cases:
            // 1. ES6 "named evaluation" - bundlers may inline anonymous classes into object literals,
            //    causing the class to inherit the property key name "instanceOf" instead of its
            //    original name (per ECMAScript SetFunctionName semantics).
            // 2. Minification - production builds mangle class names to short identifiers like "ge".
            // See: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/name
            const expectedName = argSchema.instanceOfName;
            return argValidationError(
              argName,
              expectedName
                ? `must be an instance of ${expectedName}.`
                : "must match the required class type.",
              options
            );
          }
        } else if (typeof instanceOf === "string") {
          // Model string format: "model:user"
          const modelType = instanceOf.replace(/^model:/, "");

          // Try to look up the model class via registry
          const klass = owner?.factoryFor?.(`model:${modelType}`)?.class;
          if (klass && klass !== RestModel) {
            // Specific model class exists, use instanceof
            if (!(value instanceof klass)) {
              return argValidationError(
                argName,
                `must be an instance of ${modelType} model.`,
                options
              );
            }
          } else {
            // No specific class or RestModel fallback, check RestModel + __type
            if (!(value instanceof RestModel) || value.__type !== modelType) {
              return argValidationError(
                argName,
                `must be an instance of ${modelType} model.`,
                options
              );
            }
          }
        }
      }

      // Validate properties if schema is defined
      if (argSchema.properties) {
        for (const [propName, propDef] of Object.entries(
          argSchema.properties
        )) {
          const propValue = value[propName];

          // Check required properties
          if (propDef.required && propValue === undefined) {
            const propPath = `${argName}.${propName}`;
            return argValidationError(propPath, `is required.`, options);
          }

          // Recursively validate property value
          if (propValue !== undefined) {
            const propError = validateArgValue(
              propValue,
              propDef,
              `${argName}.${propName}`,
              options
            );
            if (propError) {
              return propError;
            }
          }
        }
      }
      break;
    }

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
 * @param {Object} [options] - Optional configuration.
 * @param {string|null} [options.contextName] - Optional entity name for context.
 * @param {string} [options.contextType] - The entity type for error prefix (e.g., "Block", "Condition").
 * @returns {ValidationError|null} Validation error if validation fails, null otherwise.
 */
export function validateArrayItemType(
  item,
  itemType,
  argName,
  index,
  options = {}
) {
  const indexedArgName = `${argName}[${index}]`;

  switch (itemType) {
    case "string":
      if (typeof item !== "string") {
        return argValidationError(
          indexedArgName,
          `must be a string, got ${typeof item}.`,
          options
        );
      }
      break;

    case "number":
      if (typeof item !== "number" || Number.isNaN(item)) {
        return argValidationError(
          indexedArgName,
          `must be a number, got ${typeof item}.`,
          options
        );
      }
      break;

    case "boolean":
      if (typeof item !== "boolean") {
        return argValidationError(
          indexedArgName,
          `must be a boolean, got ${typeof item}.`,
          options
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
 * @param {Object} [options={}] - Optional configuration.
 * @param {Object} [options.owner] - Ember owner for registry lookups (used for "model:*" instanceOf).
 * @throws {BlockError} If validation fails.
 */
export function validateArgsAgainstSchema(
  providedArgs,
  schema,
  pathPrefix,
  options = {}
) {
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
      const typeError = validateArgValue(value, argDef, argName, options);
      if (typeError) {
        throw new BlockError(typeError.message, {
          path: `${pathPrefix}.${typeError.path}`,
        });
      }
    }
  }
}
