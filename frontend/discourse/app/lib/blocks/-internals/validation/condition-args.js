// @ts-check
/**
 * Condition-specific arg validation.
 *
 * This module adapts the shared arg validation utilities from args.js
 * for use with block conditions. Key differences from block arg validation:
 * - Error messages use "Condition" instead of "Block"
 * - The "default" property is not allowed (conditions don't use defaults)
 * - Type validation happens at registration time
 *
 * @module discourse/lib/blocks/-internals/validation/condition-args
 */

import { BlockError } from "discourse/lib/blocks/-internals/error";
import {
  VALID_ARG_SCHEMA_PROPERTIES,
  validateArgName,
  validateArgSchemaEntry,
  validateArgValue,
} from "discourse/lib/blocks/-internals/validation/args";

/**
 * Disallowed properties for condition arg schemas.
 * Maps property names to their specific error messages.
 * The "default" property is disallowed because conditions don't apply defaults -
 * they check explicitly for undefined values to determine what was provided.
 */
const DISALLOWED_CONDITION_PROPERTIES = Object.freeze({
  default: "Conditions do not support default values.",
});

/**
 * Valid properties for condition arg schemas.
 * Includes all standard arg properties except those in DISALLOWED_CONDITION_PROPERTIES.
 */
export const VALID_CONDITION_ARG_PROPERTIES = Object.freeze(
  VALID_ARG_SCHEMA_PROPERTIES.filter(
    (p) => !Object.hasOwn(DISALLOWED_CONDITION_PROPERTIES, p)
  )
);

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
    if (
      !validateArgName(argName, {
        entityName: conditionType,
        entityType: "Condition",
      })
    ) {
      continue;
    }

    // Conditions have no additional validation after the shared entry validation
    validateArgSchemaEntry(argDef, argName, {
      entityName: conditionType,
      entityType: "Condition",
      validProperties: VALID_CONDITION_ARG_PROPERTIES,
      disallowedProperties: DISALLOWED_CONDITION_PROPERTIES,
      allowAnyType: true,
    });
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

    // Skip validation for undefined values or "any" type
    if (value === undefined || argDef.type === "any") {
      continue;
    }

    // Validate type if value is provided
    const typeError = validateArgValue(value, argDef, argName);
    if (typeError) {
      throw new BlockError(
        formatConditionArgError(
          typeError.path,
          typeError.message.replace(/^Arg "[^"]+" /, ""),
          conditionType
        ),
        { path: path ? `${path}.${typeError.path}` : typeError.path }
      );
    }
  }
}
