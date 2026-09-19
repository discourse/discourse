/**
 * Shared arg validation utilities.
 *
 * This module provides generic validation functions for argument schemas
 * used by both blocks and conditions. Entity-specific validation logic
 * lives in separate modules:
 * - block-args.ts - block-specific validation
 * - condition-args.ts - condition-specific validation
 */
import type { ArgSchema, ArgType } from "discourse/blocks/types";
import {
  BlockError,
  raiseBlockError,
} from "discourse/lib/blocks/-internals/error";
import { formatWithSuggestion } from "discourse/lib/string-similarity";
import RestModel from "discourse/models/rest";

/**
 * A validation error result containing the error message and the path
 * to the argument that failed validation.
 */
export interface ValidationError {
  /** The formatted error message. */
  message: string;
  /** The path to the invalid argument (e.g., "test.name"). */
  path: string;
}

/**
 * Error-message context shared by the arg-value validation functions below.
 */
export interface ArgErrorContext {
  /** Optional entity name for context (e.g., block name). */
  contextName?: string | null;
  /** The entity type for the prefix (e.g., "Block", "Condition"). */
  contextType?: string;
}

/**
 * The minimal owner surface `validateArgValue` needs to resolve a `"model:*"`
 * `instanceOf` reference to its registered class. Modeled as a narrow local
 * shape rather than the full `@ember/owner` `Owner` — whose `factoryFor()` is
 * generic over literal `"type:name"` strings — because the model name here is
 * only known at runtime.
 */
interface ModelRegistryOwner {
  factoryFor?: (fullName: string) => { class?: unknown } | undefined;
}

/** Options accepted by `validateArgValue` and `validateArgsAgainstSchema`. */
export interface ValidateArgValueOptions extends ArgErrorContext {
  /** Ember owner for registry lookups (used for `"model:*"` `instanceOf`). */
  owner?: ModelRegistryOwner | null;
}

/**
 * Valid arg name pattern: must be a valid JavaScript identifier.
 * Starts with a letter, followed by letters, numbers, or underscores.
 * Note: Names starting with underscore are reserved for internal use.
 */
export const VALID_ARG_NAME_PATTERN = /^[a-zA-Z][a-zA-Z0-9_]*$/;

/**
 * Reserved argument names that cannot be used in block/condition arg schemas.
 * These are used internally by the block system and would conflict with
 * user-provided args. Names starting with underscore are also reserved.
 */
export const RESERVED_ARG_NAMES: readonly string[] = Object.freeze([
  "args",
  "block",
  "classNames",
  "containerArgs",
  "id",
  "outletArgs",
  "outletName",
  "children",
  "conditions",
  // Note: Names starting with underscore (e.g., __block$, __visible, __hierarchy)
  // are automatically reserved via the argName.startsWith("_") check in isReservedArgName()
]);

/**
 * Checks if an argument name is reserved for internal use.
 * Reserved names include explicit names in RESERVED_ARG_NAMES and
 * any name starting with underscore (private by convention).
 *
 * @param argName - The argument name to check
 * @returns True if the name is reserved
 */
export function isReservedArgName(argName: string): boolean {
  return RESERVED_ARG_NAMES.includes(argName) || argName.startsWith("_");
}

/**
 * Valid arg types for schema definitions.
 */
export const VALID_ARG_TYPES: readonly ArgType[] = Object.freeze([
  "string",
  "number",
  "boolean",
  "array",
  "object",
  "any",
]);

/** Valid item types for array args. */
type ArgItemType = NonNullable<ArgSchema["itemType"]>;

/**
 * Valid item types for array args.
 */
export const VALID_ITEM_TYPES: readonly ArgItemType[] = Object.freeze([
  "string",
  "number",
  "boolean",
]);

/**
 * Valid properties for arg schema definitions.
 */
export const VALID_ARG_SCHEMA_PROPERTIES: readonly string[] = Object.freeze([
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
 * A schema property validation rule, describing which arg types the
 * property is valid for and how to validate its value.
 */
interface SchemaPropertyRule {
  /** Arg types that can use this property. */
  allowedTypes: ArgType[];
  /** Validates the property's value. Omitted when checked elsewhere (e.g. via
   *  `formatWithSuggestion` or recursive schema validation). */
  valueCheck?: (value: unknown) => boolean;
  /** Error message if `valueCheck` fails. */
  valueError?: string;
  /** Text to append for type restriction errors (e.g., "string or array"). */
  typeErrorSuffix: string;
}

/**
 * Schema property rules for declarative validation.
 * Each rule defines:
 * - allowedTypes: arg types that can use this property
 * - valueCheck: function to validate the property value
 * - valueError: error message if value check fails
 * - typeErrorSuffix: text to append for type restriction errors (e.g., "string or array")
 */
export const SCHEMA_PROPERTY_RULES: Readonly<
  Record<string, SchemaPropertyRule>
> = Object.freeze({
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
    valueCheck: (v) => Number.isInteger(v) && (v as number) >= 0,
    valueError: "Must be a non-negative integer.",
    typeErrorSuffix: "string or array",
  },
  maxLength: {
    allowedTypes: ["string", "array"],
    valueCheck: (v) => Number.isInteger(v) && (v as number) >= 0,
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

/** Options accepted by the schema-property validation helpers below. */
interface EntityErrorOptions {
  /** The entity name for error messages. */
  entityName?: string | null;
  /** The entity type for error messages. */
  entityType?: string;
}

/**
 * Validates a schema property against its rule.
 *
 * @param argDef - The argument definition.
 * @param argName - The argument name.
 * @param prop - The property name.
 * @param options - Optional configuration.
 */
export function validateSchemaProperty(
  argDef: ArgSchema,
  argName: string,
  prop: keyof ArgSchema,
  options: EntityErrorOptions = {}
): void {
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
 * @param argDef - The argument definition.
 * @param argName - The argument name for error messages.
 * @param properties - Array of property names that are mutually exclusive.
 * @param options - Optional configuration.
 */
export function validateMutuallyExclusive(
  argDef: ArgSchema,
  argName: string,
  properties: readonly (keyof ArgSchema)[],
  options: EntityErrorOptions & {
    /** Label for the argument (e.g., "arg", "childArgs arg"). */
    argLabel?: string;
    /** Custom reason message. */
    reason?: string;
  } = {}
): void {
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

/** The names of `ArgSchema`'s numeric range-pair properties. */
type NumericRangeProperty = "min" | "max" | "minLength" | "maxLength";

/**
 * Validates a min/max range pair in the schema.
 *
 * @param argDef - The argument definition.
 * @param argName - The argument name.
 * @param minProp - The min property name.
 * @param maxProp - The max property name.
 * @param options - Optional configuration.
 */
export function validateRangePair(
  argDef: ArgSchema,
  argName: string,
  minProp: NumericRangeProperty,
  maxProp: NumericRangeProperty,
  options: EntityErrorOptions = {}
): void {
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

/** Options accepted by `validateEnumArray`. */
interface ValidateEnumArrayOptions extends EntityErrorOptions {
  /** The enum array value to validate. */
  enumValue: unknown;
  /** Property name ("enum" or "itemEnum"). */
  propName: string;
  /** Expected type for values, or undefined to skip type check. */
  expectedType?: string;
  /** The argument name for error messages. */
  argName: string;
}

/**
 * Validates an enum-like array property (enum or itemEnum).
 * Checks that the value is a non-empty array and all items match the expected type.
 *
 * @param options - Validation options.
 */
function validateEnumArray({
  enumValue,
  propName,
  expectedType,
  argName,
  entityName,
  entityType,
}: ValidateEnumArrayOptions): void {
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
 * @param argDef - The argument definition.
 * @param argName - The argument name.
 * @param options - Optional configuration.
 */
export function validateCommonSchemaProperties(
  argDef: ArgSchema,
  argName: string,
  options: EntityErrorOptions = {}
): void {
  const { entityName, entityType = "Block" } = options;
  const context = { entityName, entityType };

  // Validate schema properties using declarative rules (type restrictions + value checks)
  // `Object.keys()` widens to `string[]`; every key of `SCHEMA_PROPERTY_RULES`
  // is a valid `ArgSchema` property name.
  for (const prop of Object.keys(
    SCHEMA_PROPERTY_RULES
  ) as (keyof ArgSchema)[]) {
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

/** Options accepted by `validateArgName`. */
interface ValidateArgNameOptions extends EntityErrorOptions {
  /** Label for error messages (e.g., "childArgs arg"). */
  argLabel?: string;
}

/**
 * Validates an argument name format.
 *
 * @param argName - The argument name to validate.
 * @param options - Optional configuration.
 * @returns True if valid, false if invalid (and error raised).
 */
export function validateArgName(
  argName: string,
  options: ValidateArgNameOptions = {}
): boolean {
  const { entityName, entityType = "Block", argLabel = "arg" } = options;

  if (!VALID_ARG_NAME_PATTERN.test(argName)) {
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} name "${argName}" is invalid. ` +
        `Arg names must start with a letter and contain only letters, numbers, and underscores.`
    );
    return false;
  }

  // Check for reserved names (entry-level properties and underscore-prefixed names)
  if (isReservedArgName(argName)) {
    raiseBlockError(
      `${entityType} "${entityName}": ${argLabel} name "${argName}" is reserved. ` +
        `Reserved names are used as entry-level properties (id, children, conditions, etc.) or for internal use.`
    );
    return false;
  }

  return true;
}

/** Options accepted by `validateArgSchemaEntry`. */
export interface ValidateArgSchemaEntryOptions extends EntityErrorOptions {
  /** List of valid schema properties. */
  validProperties: readonly string[];
  /** Map of property names to their specific error messages. Properties in
   *  this map trigger a "disallowed" error instead of "unknown". */
  disallowedProperties?: Record<string, string>;
  /** If true, allow type: "any" (for conditions only). */
  allowAnyType?: boolean;
  /** Label for error messages (e.g., "childArgs arg"). */
  argLabel?: string;
}

/**
 * Validates a single arg schema entry (argDef).
 * Shared logic between block args, childArgs, and condition args validation.
 *
 * @param argDef - The argument definition.
 * @param argName - The argument name.
 * @param options - Configuration options.
 * @returns True if validation should continue with caller-specific logic, false if
 *   validation should stop (e.g., missing type, type: "any" with allowAnyType).
 */
export function validateArgSchemaEntry(
  argDef: ArgSchema,
  argName: string,
  options: ValidateArgSchemaEntryOptions
): boolean {
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
      const prop = disallowed[0]!;
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
 * @param argName - The argument name (used as the path).
 * @param message - The error message (without arg prefix).
 * @param options - Optional configuration.
 * @returns The validation error object with message and path.
 */
function argValidationError(
  argName: string,
  message: string,
  options: ArgErrorContext = {}
): ValidationError {
  const { contextName, contextType } = options;
  const formattedMessage = contextName
    ? `${contextType} "${contextName}": arg "${argName}" ${message}`
    : `Arg "${argName}" ${message}`;
  return { message: formattedMessage, path: argName };
}

/**
 * Validates a single argument value against its schema definition.
 *
 * @param value - The argument value.
 * @param argSchema - The schema definition for this arg.
 * @param argName - The argument name for error messages.
 * @param options - Optional configuration.
 * @returns Validation error if validation fails, null otherwise.
 */
export function validateArgValue(
  value: unknown,
  argSchema: ArgSchema,
  argName: string,
  options: ValidateArgValueOptions = {}
): ValidationError | null {
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
        const suggestion = formatWithSuggestion(value, enumValues as string[]);
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
          const item: unknown = value[i];
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
          const item: unknown = value[i];
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
            if (!(value instanceof (klass as abstract new () => object))) {
              return argValidationError(
                argName,
                `must be an instance of ${modelType} model.`,
                options
              );
            }
          } else {
            // No specific class or RestModel fallback, check RestModel + __type.
            // `value instanceof RestModel` narrows `value` to `RestModel`,
            // which (like `LayoutEntry`) has no index signature — the
            // two-step cast reads its dynamic `__type` field regardless.
            if (
              !(value instanceof RestModel) ||
              (value as unknown as Record<string, unknown>)["__type"] !==
                modelType
            ) {
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
          const propValue = (value as Record<string, unknown>)[propName];

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
 * @param item - The array item.
 * @param itemType - The expected type ("string", "number", "boolean").
 * @param argName - The argument name for error messages.
 * @param index - The array index for error messages.
 * @param options - Optional configuration.
 * @returns Validation error if validation fails, null otherwise.
 */
export function validateArrayItemType(
  item: unknown,
  itemType: ArgItemType,
  argName: string,
  index: number,
  options: ArgErrorContext = {}
): ValidationError | null {
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
 * @param providedArgs - The arguments to validate.
 * @param schema - The schema to validate against.
 * @param pathPrefix - Prefix for error paths (e.g., "args" or "containerArgs").
 * @param options - Optional configuration.
 * @throws BlockError if validation fails.
 */
export function validateArgsAgainstSchema(
  providedArgs: Record<string, unknown>,
  schema: Record<string, ArgSchema>,
  pathPrefix: string,
  options: ValidateArgValueOptions = {}
): void {
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
