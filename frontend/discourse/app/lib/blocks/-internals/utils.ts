/**
 * Utility functions for the block system.
 */
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import type { BlockClass } from "discourse/lib/blocks/-internals/types";
import type { ValidationErrorDetails } from "discourse/lib/blocks/-internals/validation/args";

/**
 * Validation context passed through the layout validation pipeline for error
 * reporting. Created via `createValidationContext()` to ensure consistent
 * structure across all validation functions.
 *
 * The following properties are added by validation code after initial context
 * creation: `errorPath` (full path to the error, e.g.
 * "layout[0].conditions.params.categoryId"), `conditionsPath` (path within
 * conditions, e.g. "params.categoryId"), and `conditions` (the conditions
 * object for error display).
 */
export interface ValidationContext {
  /** The name of the outlet being validated. */
  outletName: string;
  /** The name of the block, if resolved. */
  blockName?: string | null;
  /** The hierarchical path to this entry (e.g., "layout[0].children[1]"). */
  path: string;
  /** The block entry object being validated. */
  entry?: Record<string, unknown> | null;
  /** Error captured at the call site for stack traces. */
  callSiteError?: Error | null;
  /** The root layout array for error display. */
  rootLayout?: Array<Record<string, unknown>> | null;
  /** Full path to the error (e.g., "layout[0].conditions.params.categoryId"). */
  errorPath?: string;
  /** Path within conditions (e.g., "params.categoryId"). */
  conditionsPath?: string;
  /** The conditions object for error display. */
  conditions?: unknown;
  /** Structured payload preserved through re-throws for field-level errors. */
  details?: ValidationErrorDetails | ValidationErrorDetails[] | null;
}

/**
 * Parameters accepted by `createValidationContext()`.
 */
export interface CreateValidationContextParams {
  /** The name of the outlet being validated. */
  outletName: string;
  /** The name of the block, if resolved. */
  blockName?: string | null;
  /** The hierarchical path to this entry. */
  path: string;
  /** The block entry object being validated. */
  entry?: Record<string, unknown> | null;
  /** Error captured at the call site. */
  callSiteError?: Error | null;
  /** The root layout array for error display. */
  rootLayout?: Array<Record<string, unknown>> | null;
}

/**
 * Creates a validation context object for error reporting.
 * Centralizes context creation to ensure consistent structure across
 * all validation functions.
 */
export function createValidationContext({
  outletName,
  blockName = null,
  path,
  entry = null,
  callSiteError = null,
  rootLayout = null,
}: CreateValidationContextParams): ValidationContext {
  return { outletName, blockName, path, entry, callSiteError, rootLayout };
}

/**
 * Builds a hierarchical error path by joining path segments.
 * Used to construct full paths for error messages (e.g., "layout[0].args.title").
 *
 * @param basePath - The base path (e.g., "layout[0]").
 * @param segment - The segment to append (e.g., "args.title").
 * @returns Combined path with dot separator, or the non-empty path if one is missing.
 *
 * @example
 * ```
 * buildErrorPath("layout[0]", "args.title")
 * // => "layout[0].args.title"
 *
 * buildErrorPath("", "args")
 * // => "args"
 * ```
 */
export function buildErrorPath(basePath: string, segment: string): string {
  if (!basePath) {
    return segment;
  }
  if (!segment) {
    return basePath;
  }
  return `${basePath}.${segment}`;
}

/**
 * The `default` metadata for a single block argument, as read from the
 * `@block` decorator's args schema.
 */
export interface BlockArgSchemaEntry {
  default?: unknown;
}

/**
 * Applies default values from block metadata to provided args.
 *
 * When a block is configured with args, this function merges the provided
 * args with default values from the block's metadata schema. Default values
 * are only applied when the arg is undefined in the provided args.
 *
 * @param ComponentClass - The block component class.
 * @param providedArgs - The args provided in the layout entry.
 * @returns A new object with defaults applied for missing args.
 *
 * @example
 * ```javascript
 * // Block metadata: { args: { title: { default: "Hello" }, count: { default: 0 } } }
 * applyArgDefaults(MyBlock, { title: "Custom" });
 * // => { title: "Custom", count: 0 }
 * ```
 */
export function applyArgDefaults(
  ComponentClass: BlockClass,
  providedArgs: Record<string, unknown>
): Readonly<Record<string, unknown>> {
  const schema = getBlockMetadata(ComponentClass)?.args as
    | Record<string, BlockArgSchemaEntry>
    | null
    | undefined;

  const result: Record<string, unknown> = { ...providedArgs };

  // apply default values
  if (schema) {
    for (const [argName, argDef] of Object.entries(schema)) {
      if (result[argName] === undefined && argDef.default !== undefined) {
        result[argName] = argDef.default;
      }
    }
  }

  return Object.freeze(result);
}

/**
 * Performs a shallow comparison of two args objects.
 *
 * Compares top-level values using strict equality (===). Does not perform
 * deep comparison of nested objects. Used to determine if cached curried
 * components can be reused.
 *
 * @param a - First args object.
 * @param b - Second args object.
 * @returns True if the args are shallowly equal, false otherwise.
 */
export function shallowArgsEqual(
  a: Record<string, unknown> | null | undefined,
  b: Record<string, unknown> | null | undefined
): boolean {
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
 * @param obj - The object to get the value from.
 * @param path - Dot-notation path (e.g., "user.trust_level").
 * @returns The value at the path, or undefined if not found or if any
 *   intermediate value is null/undefined.
 *
 * @example
 * ```
 * const user = { profile: { name: "Alice", settings: { theme: "dark" } } };
 * getByPath(user, "profile.name"); // "Alice"
 * getByPath(user, "profile.settings.theme"); // "dark"
 * getByPath(user, "profile.missing"); // undefined
 * getByPath(user, "profile.settings.missing.deep"); // undefined (safe)
 * ```
 */
export function getByPath(obj: unknown, path: string): unknown {
  if (!obj || !path) {
    return undefined;
  }

  const parts = path.split(".");
  let current: unknown = obj;

  for (const part of parts) {
    if (current === null || current === undefined) {
      return undefined;
    }
    current = (current as Record<string, unknown>)[part];
  }

  return current;
}
