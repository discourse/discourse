// @ts-check
import { validateConditionArgsSchema } from "discourse/lib/blocks/condition-arg-validation";
import { validateConstraintsSchema } from "discourse/lib/blocks/constraint-validation";
import { formatWithSuggestion } from "discourse/lib/string-similarity";
import { BlockCondition } from "./condition";

/**
 * Valid sourceType values for the decorator config.
 * @constant {ReadonlyArray<string>}
 */
const VALID_SOURCE_TYPES = Object.freeze(["none", "outletArgs", "object"]);

/**
 * Valid config keys for the decorator.
 * @constant {ReadonlyArray<string>}
 */
const VALID_CONFIG_KEYS = Object.freeze([
  "type",
  "sourceType",
  "args",
  "constraints",
  "validate",
]);

/**
 * WeakSet tracking decorated classes.
 * Private - only accessible via isDecoratedCondition().
 */
const decoratedConditions = new WeakSet();

/**
 * Checks if a class was decorated with @blockCondition.
 * Used by the block registration system to reject non-decorated classes.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {Function} ConditionClass - The class to check.
 * @returns {boolean} True if the class was decorated.
 */
export function isDecoratedCondition(ConditionClass) {
  return decoratedConditions.has(ConditionClass);
}

/**
 * Decorator to define a block condition with declarative arg validation.
 *
 * The class must extend BlockCondition. The decorator adds static getters
 * for type, sourceType, argsSchema, constraints, validateFn, and validArgKeys
 * based on the provided config. Unknown config keys are rejected with helpful suggestions.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {Object} config - Condition configuration.
 * @param {string} config.type - Unique condition type identifier.
 * @param {"none"|"outletArgs"|"object"} [config.sourceType="none"] - How source parameter is handled.
 * @param {Object} [config.args={}] - Arg schema definitions (type, required, min, max, pattern, etc.).
 *   An empty object `{}` for an arg means any type is allowed.
 * @param {Object} [config.constraints] - Cross-arg constraints (atLeastOne, exactlyOne, allOrNone, atMostOne).
 * @param {Function} [config.validate] - Custom validation function called at registration time.
 *   Receives args object, returns error string/array or null.
 * @throws {Error} If config is invalid or class doesn't extend BlockCondition.
 *
 * @example
 * import { blockCondition, BlockCondition } from "discourse/blocks/conditions";
 *
 * @blockCondition({
 *   type: "user",
 *   sourceType: "outletArgs",
 *   args: {
 *     loggedIn: { type: "boolean" },
 *     admin: { type: "boolean" },
 *     minTrustLevel: { type: "number", min: 0, max: 4, integer: true },
 *     groups: { type: "array", itemType: "string" },
 *   },
 *   validate(args) {
 *     if (args.loggedIn === false && args.admin) {
 *       return "Cannot use loggedIn: false with admin condition.";
 *     }
 *     return null;
 *   }
 * })
 * export default class BlockUserCondition extends BlockCondition {
 *   @service currentUser;
 *   evaluate(args, context) { ... }
 * }
 *
 * @example
 * // With constraints
 * @blockCondition({
 *   type: "setting",
 *   sourceType: "object",
 *   args: {
 *     name: { type: "string", required: true },
 *     enabled: { type: "boolean" },
 *     equals: {},  // any type
 *     includes: { type: "array" },
 *   },
 *   constraints: {
 *     atMostOne: ["enabled", "equals", "includes"],
 *   },
 * })
 */
export function blockCondition(config) {
  const {
    type,
    sourceType = "none",
    args: argsSchema = {},
    constraints,
    validate: validateFn,
  } = config;

  // Validate config at decoration time
  if (!type || typeof type !== "string") {
    throw new Error("blockCondition: `type` is required and must be a string.");
  }

  // Validate sourceType is one of the allowed values
  if (!VALID_SOURCE_TYPES.includes(sourceType)) {
    const suggestion = formatWithSuggestion(sourceType, VALID_SOURCE_TYPES);
    throw new Error(
      `blockCondition: Invalid \`sourceType\` ${suggestion}. ` +
        `Valid values are: ${VALID_SOURCE_TYPES.join(", ")}.`
    );
  }

  // Validate no unknown config keys (catches typos)
  const unknownKeys = Object.keys(config).filter(
    (key) => !VALID_CONFIG_KEYS.includes(key)
  );
  if (unknownKeys.length > 0) {
    const suggestions = unknownKeys
      .map((key) => formatWithSuggestion(key, VALID_CONFIG_KEYS))
      .join(", ");
    throw new Error(
      `blockCondition: unknown config key(s): ${suggestions}. ` +
        `Valid keys are: ${VALID_CONFIG_KEYS.join(", ")}.`
    );
  }

  // Validate args schema at decoration time (catches schema definition errors)
  if (argsSchema && typeof argsSchema === "object") {
    validateConditionArgsSchema(argsSchema, type);
  }

  // Validate constraints schema at decoration time
  if (constraints) {
    // Constraints reference args schema - validate they're compatible
    validateConstraintsSchema(constraints, argsSchema, `Condition "${type}"`);
  }

  // Validate that validate is a function if provided
  if (validateFn !== undefined && typeof validateFn !== "function") {
    throw new Error(
      `blockCondition: "validate" must be a function, got ${typeof validateFn}.`
    );
  }

  // Freeze schema and compute derived validArgKeys
  const frozenSchema = Object.freeze({ ...argsSchema });
  const frozenConstraints = constraints
    ? Object.freeze({ ...constraints })
    : undefined;
  const argKeys = Object.freeze(Object.keys(argsSchema));
  const allKeys =
    sourceType !== "none" ? Object.freeze([...argKeys, "source"]) : argKeys;

  return function decorator(TargetClass) {
    // Validate that the class extends BlockCondition
    if (!(TargetClass.prototype instanceof BlockCondition)) {
      throw new Error(
        `blockCondition: ${TargetClass.name} must extend BlockCondition.`
      );
    }

    // Define static getters (non-configurable to prevent reassignment)
    Object.defineProperty(TargetClass, "type", {
      get: () => type,
      configurable: false,
    });
    Object.defineProperty(TargetClass, "sourceType", {
      get: () => sourceType,
      configurable: false,
    });
    Object.defineProperty(TargetClass, "argsSchema", {
      get: () => frozenSchema,
      configurable: false,
    });
    Object.defineProperty(TargetClass, "constraints", {
      get: () => frozenConstraints,
      configurable: false,
    });
    Object.defineProperty(TargetClass, "validateFn", {
      get: () => validateFn,
      configurable: false,
    });
    // validArgKeys combines argsSchema keys with "source" when sourceType !== "none"
    Object.defineProperty(TargetClass, "validArgKeys", {
      get: () => allKeys,
      configurable: false,
    });

    // Track as decorated so Blocks service can verify
    decoratedConditions.add(TargetClass);

    return TargetClass;
  };
}
