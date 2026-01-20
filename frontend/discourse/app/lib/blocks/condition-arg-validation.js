// @ts-check
/**
 * Condition-specific arg validation.
 *
 * This module adapts the shared arg validation utilities from arg-validation.js
 * for use with block conditions. Key differences from block arg validation:
 * - Error messages use "Condition" instead of "Block"
 * - The "default" property is not allowed (conditions don't use defaults)
 * - Type validation happens at registration time
 *
 * @module discourse/lib/blocks/condition-arg-validation
 */

import {
  VALID_ARG_NAME_PATTERN,
  VALID_ARG_SCHEMA_PROPERTIES,
  VALID_ARG_TYPES,
  VALID_ITEM_TYPES,
  validateArgValue,
} from "discourse/lib/blocks/arg-validation";
import { BlockError, raiseBlockError } from "discourse/lib/blocks/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Properties NOT allowed for condition arg schemas.
 * The "default" property is excluded because conditions don't apply defaults -
 * they check explicitly for undefined values to determine what was provided.
 */
const DISALLOWED_CONDITION_PROPERTIES = ["default"];

/**
 * Valid properties for condition arg schemas.
 * Includes all standard arg properties except those in DISALLOWED_CONDITION_PROPERTIES.
 */
export const VALID_CONDITION_ARG_PROPERTIES = Object.freeze(
  VALID_ARG_SCHEMA_PROPERTIES.filter(
    (p) => !DISALLOWED_CONDITION_PROPERTIES.includes(p)
  )
);

/**
 * Schema property rules for declarative validation.
 * Reused from arg-validation.js logic.
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
 * @param {string} conditionType - The condition type name.
 */
function validateSchemaProperty(prop, argDef, argName, conditionType) {
  const rule = SCHEMA_PROPERTY_RULES[prop];
  if (!rule || argDef[prop] === undefined) {
    return;
  }

  // Check type restriction
  if (!rule.allowedTypes.includes(argDef.type)) {
    raiseBlockError(
      `Condition "${conditionType}": arg "${argName}" has "${prop}" but type is "${argDef.type}". ` +
        `"${prop}" is only valid for ${rule.typeErrorSuffix} type.`
    );
  }

  // Check value validity
  if (!rule.valueCheck(argDef[prop])) {
    raiseBlockError(
      `Condition "${conditionType}": arg "${argName}" has invalid "${prop}" value. ${rule.valueError}`
    );
  }
}

/**
 * Validates a min/max range pair in the schema.
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} conditionType - The condition type name.
 * @param {string} minProp - The min property name.
 * @param {string} maxProp - The max property name.
 */
function validateRangePair(argDef, argName, conditionType, minProp, maxProp) {
  if (
    argDef[minProp] !== undefined &&
    argDef[maxProp] !== undefined &&
    argDef[minProp] > argDef[maxProp]
  ) {
    raiseBlockError(
      `Condition "${conditionType}": arg "${argName}" has ${minProp} (${argDef[minProp]}) greater than ${maxProp} (${argDef[maxProp]}).`
    );
  }
}

/**
 * Validates the arg schema definition passed to the @blockCondition decorator.
 * Enforces strict schema format - unknown properties are not allowed.
 * Called at decoration time to catch schema errors early.
 *
 * @param {Object} argsSchema - The args schema object from decorator options.
 * @param {string} conditionType - Condition type name for error messages.
 * @throws {Error} If schema is invalid.
 */
export function validateConditionArgsSchema(argsSchema, conditionType) {
  if (!argsSchema || typeof argsSchema !== "object") {
    return;
  }

  for (const [argName, argDef] of Object.entries(argsSchema)) {
    // Validate arg name format
    if (!VALID_ARG_NAME_PATTERN.test(argName)) {
      raiseBlockError(
        `Condition "${conditionType}": arg name "${argName}" is invalid. ` +
          `Arg names must start with a letter and contain only letters, numbers, and underscores.`
      );
      continue;
    }

    // Allow empty object for "any type" args (e.g., equals in setting condition)
    if (!argDef || typeof argDef !== "object") {
      raiseBlockError(
        `Condition "${conditionType}": arg "${argName}" must be an object.`
      );
      continue;
    }

    // Check for unknown properties
    const unknownProps = Object.keys(argDef).filter(
      (prop) => !VALID_CONDITION_ARG_PROPERTIES.includes(prop)
    );
    if (unknownProps.length > 0) {
      // Check if it's a disallowed property specifically
      const disallowed = unknownProps.filter((p) =>
        DISALLOWED_CONDITION_PROPERTIES.includes(p)
      );
      if (disallowed.length > 0) {
        raiseBlockError(
          `Condition "${conditionType}": arg "${argName}" has disallowed property "${disallowed[0]}". ` +
            `Conditions do not support default values.`
        );
      } else {
        const suggestions = unknownProps.map((prop) =>
          formatWithSuggestion(prop, VALID_CONDITION_ARG_PROPERTIES)
        );
        raiseBlockError(
          `Condition "${conditionType}": arg "${argName}" has unknown properties: ${suggestions.join(", ")}. ` +
            `Valid properties are: ${VALID_CONDITION_ARG_PROPERTIES.join(", ")}.`
        );
      }
    }

    // Empty schema means "any type" - skip type validation
    if (Object.keys(argDef).length === 0) {
      continue;
    }

    // Type is required if any other properties are specified
    if (!argDef.type) {
      raiseBlockError(
        `Condition "${conditionType}": arg "${argName}" is missing required "type" property.`
      );
      continue;
    }

    // Validate type
    if (!VALID_ARG_TYPES.includes(argDef.type)) {
      const suggestion = formatWithSuggestion(argDef.type, VALID_ARG_TYPES);
      raiseBlockError(
        `Condition "${conditionType}": arg "${argName}" has invalid type ${suggestion}. ` +
          `Valid types are: ${VALID_ARG_TYPES.join(", ")}.`
      );
    }

    // itemType is only valid for array type
    if (argDef.itemType !== undefined && argDef.type !== "array") {
      raiseBlockError(
        `Condition "${conditionType}": arg "${argName}" has "itemType" but type is "${argDef.type}". ` +
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
          `Condition "${conditionType}": arg "${argName}" has invalid itemType ${suggestion}. ` +
            `Valid item types are: ${VALID_ITEM_TYPES.join(", ")}.`
        );
      }
    }

    // Validate schema properties using declarative rules
    for (const prop of Object.keys(SCHEMA_PROPERTY_RULES)) {
      validateSchemaProperty(prop, argDef, argName, conditionType);
    }

    // Validate range pairs
    validateRangePair(argDef, argName, conditionType, "min", "max");
    validateRangePair(argDef, argName, conditionType, "minLength", "maxLength");

    // enum is only valid for string or number type
    if (
      argDef.enum !== undefined &&
      argDef.type !== "string" &&
      argDef.type !== "number"
    ) {
      raiseBlockError(
        `Condition "${conditionType}": arg "${argName}" has "enum" but type is "${argDef.type}". ` +
          `"enum" is only valid for string or number type.`
      );
    }

    // Validate enum is an array with at least one element
    if (argDef.enum !== undefined) {
      if (!Array.isArray(argDef.enum) || argDef.enum.length === 0) {
        raiseBlockError(
          `Condition "${conditionType}": arg "${argName}" has invalid "enum" value. Must be an array with at least one element.`
        );
      } else {
        // Validate all enum values match the arg type
        const expectedType = argDef.type === "string" ? "string" : "number";
        for (const enumValue of argDef.enum) {
          if (typeof enumValue !== expectedType) {
            raiseBlockError(
              `Condition "${conditionType}": arg "${argName}" enum contains invalid value "${enumValue}". All values must be ${expectedType}s.`
            );
          }
        }
      }
    }

    // Validate required is boolean
    if (argDef.required !== undefined && typeof argDef.required !== "boolean") {
      raiseBlockError(
        `Condition "${conditionType}": arg "${argName}" has invalid "required" value. Must be a boolean.`
      );
    }
  }
}

/**
 * Formats an error message for condition arg validation.
 *
 * @param {string} argName - The argument name.
 * @param {string} message - The error message.
 * @param {string} conditionType - The condition type name.
 * @returns {string} Formatted error message.
 */
function formatConditionArgError(argName, message, conditionType) {
  return `Condition "${conditionType}": arg "${argName}" ${message}`;
}

/**
 * Validates provided arg values against the condition's schema.
 * Called at block registration time to catch invalid values early.
 *
 * @param {Object} args - The arguments provided to the condition.
 * @param {Object} argsSchema - The condition's args schema.
 * @param {string} conditionType - The condition type for error messages.
 * @param {string} path - The path to this condition in the block tree.
 * @throws {BlockError} If validation fails.
 */
export function validateConditionArgValues(
  args,
  argsSchema,
  conditionType,
  path
) {
  for (const [argName, argDef] of Object.entries(argsSchema)) {
    const value = args[argName];

    // Check required args
    if (argDef.required && value === undefined) {
      throw new BlockError(
        `Condition "${conditionType}": missing required arg "${argName}".`,
        { path: path ? `${path}.${argName}` : argName }
      );
    }

    // Skip validation for undefined values or "any type" schemas
    if (value === undefined || Object.keys(argDef).length === 0) {
      continue;
    }

    // Skip validation if no type specified (any type allowed)
    if (!argDef.type) {
      continue;
    }

    // Validate type if value is provided
    const typeError = validateArgValue(value, argDef, argName);
    if (typeError) {
      throw new BlockError(
        formatConditionArgError(
          argName,
          typeError.replace(/^Arg "[^"]+" /, ""),
          conditionType
        ),
        { path: path ? `${path}.${argName}` : argName }
      );
    }
  }
}
