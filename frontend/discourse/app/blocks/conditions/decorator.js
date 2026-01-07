/**
 * WeakSet tracking decorated classes.
 * Private - only accessible via isDecoratedCondition().
 */
const decoratedConditions = new WeakSet();

/**
 * Checks if a class was decorated with @blockCondition.
 * Used by the Blocks service to reject non-decorated classes.
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
 *
 * @param {Object} config - Condition configuration.
 * @param {string} config.type - Unique condition type identifier.
 * @param {"none"|"outletArgs"|"object"} [config.sourceType="none"] - How source parameter is handled.
 * @param {string[]} config.validArgKeys - Valid argument keys (do NOT include "source").
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

  // Freeze keys and compute final list with source if applicable
  const frozenKeys = Object.freeze([...validArgKeys]);
  const allKeys =
    sourceType !== "none"
      ? Object.freeze([...frozenKeys, "source"])
      : frozenKeys;

  return function decorator(TargetClass) {
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
