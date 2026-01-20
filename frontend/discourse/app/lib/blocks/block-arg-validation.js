// @ts-check
/**
 * Block-specific arg validation.
 *
 * This module adapts the shared arg validation utilities from arg-validation.js
 * for use with blocks. Key differences from condition arg validation:
 * - Supports "default" values (conditions don't use defaults)
 * - Validates "required + default" contradiction
 * - Supports childArgs with "unique" property
 *
 * @module discourse/lib/blocks/block-arg-validation
 */

import {
  VALID_ARG_SCHEMA_PROPERTIES,
  validateArgName,
  validateArgsAgainstSchema,
  validateArgSchemaEntry,
  validateArgValue,
} from "discourse/lib/blocks/arg-validation";
import { BlockError, raiseBlockError } from "discourse/lib/blocks/error";

/**
 * Valid properties for childArgs schema definitions.
 * Includes all standard arg properties plus "unique" for sibling uniqueness validation.
 */
export const VALID_CHILD_ARG_SCHEMA_PROPERTIES = Object.freeze([
  ...VALID_ARG_SCHEMA_PROPERTIES,
  "unique",
]);

/**
 * Validates block-specific default value rules:
 * - "required + default" is contradictory (an arg with a default is never missing)
 * - Default value must match the arg's type schema
 *
 * @param {Object} argDef - The argument definition.
 * @param {string} argName - The argument name.
 * @param {string} blockName - Block name for error messages.
 * @param {string} [argLabel="arg"] - Label for error messages (e.g., "childArgs arg").
 */
function validateBlockDefaultValue(
  argDef,
  argName,
  blockName,
  argLabel = "arg"
) {
  if (argDef.required === true && argDef.default !== undefined) {
    raiseBlockError(
      `Block "${blockName}": ${argLabel} "${argName}" has both "required: true" and "default". ` +
        `These options are contradictory - an arg with a default value is never missing.`
    );
  }

  if (argDef.default !== undefined) {
    const defaultError = validateArgValue(
      argDef.default,
      argDef,
      argName,
      blockName,
      "Block"
    );
    if (defaultError) {
      raiseBlockError(
        `Block "${blockName}": ${argLabel} "${argName}" has invalid default value. ${defaultError}`
      );
    }
  }
}

/**
 * Validates the arg schema definition passed to the @block decorator.
 * Enforces strict schema format - unknown properties are not allowed.
 *
 * @param {Object} argsSchema - The args schema object from decorator options.
 * @param {string} blockName - Block name for error messages.
 * @throws {Error} If schema is invalid.
 */
export function validateArgsSchema(argsSchema, blockName) {
  if (!argsSchema || typeof argsSchema !== "object") {
    return;
  }

  for (const [argName, argDef] of Object.entries(argsSchema)) {
    if (!validateArgName(argName, blockName, "Block")) {
      continue;
    }

    const shouldContinue = validateArgSchemaEntry(argDef, argName, blockName, {
      entityType: "Block",
      validProperties: VALID_ARG_SCHEMA_PROPERTIES,
    });

    if (!shouldContinue) {
      continue;
    }

    validateBlockDefaultValue(argDef, argName, blockName);
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
      entityType: "Block",
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

    validateBlockDefaultValue(argDef, argName, blockName, "childArgs arg");
  }
}
