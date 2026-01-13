/**
 * Utility functions for the block system.
 *
 * @module discourse/lib/blocks/utils
 */

/**
 * Applies default values from block metadata to provided args.
 *
 * When a block is configured with args, this function merges the provided
 * args with default values from the block's metadata schema. Default values
 * are only applied when the arg is undefined in the provided args.
 *
 * @param {typeof import("@glimmer/component").default} ComponentClass - The block component class.
 * @param {Object} providedArgs - The args provided in the block configuration.
 * @returns {Object} A new object with defaults applied for missing args.
 *
 * @example
 * ```javascript
 * // Block metadata: { args: { title: { default: "Hello" }, count: { default: 0 } } }
 * applyArgDefaults(MyBlock, { title: "Custom" });
 * // => { title: "Custom", count: 0 }
 * ```
 */
export function applyArgDefaults(ComponentClass, providedArgs) {
  const schema = ComponentClass.blockMetadata?.args;
  if (!schema) {
    return providedArgs;
  }

  const result = { ...providedArgs };
  for (const [argName, argDef] of Object.entries(schema)) {
    if (result[argName] === undefined && argDef.default !== undefined) {
      result[argName] = argDef.default;
    }
  }
  return result;
}

/**
 * Performs a shallow comparison of two args objects.
 *
 * Compares top-level values using strict equality (===). Does not perform
 * deep comparison of nested objects. Used to determine if cached curried
 * components can be reused.
 *
 * @param {Object|null|undefined} a - First args object.
 * @param {Object|null|undefined} b - Second args object.
 * @returns {boolean} True if the args are shallowly equal, false otherwise.
 */
export function shallowArgsEqual(a, b) {
  if (a === b) {
    return true;
  }
  if (a == null || b == null) {
    return false;
  }
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  if (keysA.length !== keysB.length) {
    return false;
  }
  return keysA.every((key) => a[key] === b[key]);
}
