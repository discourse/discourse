// @ts-check
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
const VALID_CONFIG_KEYS = Object.freeze(["type", "sourceType", "validArgKeys"]);

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
 * Decorator to define a block condition.
 *
 * The class must extend BlockCondition. The decorator adds static getters
 * for type, sourceType, and validArgKeys based on the provided config.
 * Unknown config keys are rejected with helpful suggestions.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 *
 * @param {Object} config - Condition configuration.
 * @param {string} config.type - Unique condition type identifier.
 * @param {"none"|"outletArgs"|"object"} [config.sourceType="none"] - How source parameter is handled.
 * @param {string[]} config.validArgKeys - Valid argument keys (do NOT include "source").
 * @throws {Error} If config is invalid or class doesn't extend BlockCondition.
 *
 * @example
 * import { blockCondition, BlockCondition } from "discourse/blocks/conditions";
 *
 * @blockCondition({
 *   type: "myCondition",
 *   sourceType: "none",
 *   validArgKeys: ["enabled", "value"],
 * })
 * export default class MyCondition extends BlockCondition {
 *   validate(args) { ... }
 *   evaluate(args, context) { ... }
 * }
 */
export function blockCondition(config) {
  const { type, sourceType = "none", validArgKeys } = config;

  // Validate config at decoration time
  if (!type || typeof type !== "string") {
    throw new Error("blockCondition: `type` is required and must be a string.");
  }

  if (!Array.isArray(validArgKeys)) {
    throw new Error("blockCondition: `validArgKeys` must be an array.");
  }

  if (validArgKeys.includes("source")) {
    throw new Error(
      "blockCondition: Do not include 'source' in validArgKeys. " +
        "It is added automatically when sourceType !== 'none'."
    );
  }

  // Validate sourceType is one of the allowed values
  if (!VALID_SOURCE_TYPES.includes(sourceType)) {
    const suggestion = formatWithSuggestion(sourceType, VALID_SOURCE_TYPES);
    throw new Error(
      `blockCondition: Invalid \`sourceType\` ${suggestion}. ` +
        `Valid values are: ${VALID_SOURCE_TYPES.join(", ")}.`
    );
  }

  // Validate no unknown config keys (catches typos like "validArgKey" or "sourcetype")
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

  // Freeze keys and compute final list with source if applicable
  const frozenKeys = Object.freeze([...validArgKeys]);
  const allKeys =
    sourceType !== "none"
      ? Object.freeze([...frozenKeys, "source"])
      : frozenKeys;

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
    Object.defineProperty(TargetClass, "validArgKeys", {
      get: () => allKeys,
      configurable: false,
    });

    // Track as decorated so Blocks service can verify
    decoratedConditions.add(TargetClass);

    return TargetClass;
  };
}
