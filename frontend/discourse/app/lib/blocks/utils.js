/**
 * Utility functions for the block system.
 *
 * @module discourse/lib/blocks/utils
 */

/**
 * @typedef {Object} ValidationContext
 * @property {string} outletName - The name of the outlet being validated.
 * @property {string|null} [blockName=null] - The name of the block, if resolved.
 * @property {string} path - The hierarchical path to this entry (e.g., "layout[0].children[1]").
 * @property {Object|null} [entry=null] - The block entry object being validated.
 * @property {Error|null} [callSiteError=null] - Error captured at the call site for stack traces.
 * @property {Array|null} [rootLayout=null] - The root layout array for error display.
 */

/**
 * Creates a validation context object for error reporting.
 * Centralizes context creation to ensure consistent structure across
 * all validation functions.
 *
 * @param {Object} params - Context parameters.
 * @param {string} params.outletName - The name of the outlet being validated.
 * @param {string|null} [params.blockName=null] - The name of the block, if resolved.
 * @param {string} params.path - The hierarchical path to this entry.
 * @param {Object|null} [params.entry=null] - The block entry object being validated.
 * @param {Error|null} [params.callSiteError=null] - Error captured at the call site.
 * @param {Array|null} [params.rootLayout=null] - The root layout array for error display.
 * @returns {ValidationContext} A validation context object.
 */
export function createValidationContext({
  outletName,
  blockName = null,
  path,
  entry = null,
  callSiteError = null,
  rootLayout = null,
}) {
  return { outletName, blockName, path, entry, callSiteError, rootLayout };
}

/**
 * Builds a hierarchical error path by joining path segments.
 * Used to construct full paths for error messages (e.g., "layout[0].args.title").
 *
 * @param {string} basePath - The base path (e.g., "layout[0]").
 * @param {string} segment - The segment to append (e.g., "args.title").
 * @returns {string} Combined path with dot separator, or the non-empty path if one is missing.
 *
 * @example
 * buildErrorPath("layout[0]", "args.title")
 * // => "layout[0].args.title"
 *
 * buildErrorPath("", "args")
 * // => "args"
 */
export function buildErrorPath(basePath, segment) {
  if (!basePath) {
    return segment;
  }
  if (!segment) {
    return basePath;
  }
  return `${basePath}.${segment}`;
}

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

/**
 * Retrieves a value from a nested object using dot-notation path.
 *
 * This utility safely navigates through nested object properties using a
 * dot-separated path string. It handles null/undefined values gracefully
 * at any level of the path.
 *
 * @param {Object} obj - The object to get the value from.
 * @param {string} path - Dot-notation path (e.g., "user.trust_level").
 * @returns {*} The value at the path, or undefined if not found or if any
 *              intermediate value is null/undefined.
 *
 * @example
 * const user = { profile: { name: "Alice", settings: { theme: "dark" } } };
 * getByPath(user, "profile.name"); // "Alice"
 * getByPath(user, "profile.settings.theme"); // "dark"
 * getByPath(user, "profile.missing"); // undefined
 * getByPath(user, "profile.settings.missing.deep"); // undefined (safe)
 */
export function getByPath(obj, path) {
  if (!obj || !path) {
    return undefined;
  }

  const parts = path.split(".");
  let current = obj;

  for (const part of parts) {
    if (current === null || current === undefined) {
      return undefined;
    }
    current = current[part];
  }

  return current;
}
