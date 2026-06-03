/**
 * Block Decorator Validation
 *
 * This module contains validation functions used by the @block decorator.
 * These validations run at decoration time (not render time) for fail-fast behavior.
 */
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import {
  detectPatternConflicts,
  validateOutletPatterns,
  warnUnknownOutletPatterns,
} from "discourse/lib/blocks/-internals/matching/outlet-matcher";
import {
  parseBlockName,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/-internals/patterns";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Valid keys for the @block decorator options (block schema).
 *
 * @constant {ReadonlyArray<string>}
 */
export const VALID_BLOCK_OPTIONS = Object.freeze([
  "container",
  "classNames",
  "description",
  "args",
  "childArgs",
  "constraints",
  "validate",
  "allowedOutlets",
  "deniedOutlets",
  "displayName",
  "icon",
  "category",
  "previewArgs",
  "thumbnail",
  "paletteHidden",
  "transparent",
  "data",
]);

/**
 * Valid keys for the `data` option (a block's declared data dependency).
 *
 * @constant {ReadonlyArray<string>}
 */
const VALID_DATA_KEYS = Object.freeze([
  "request",
  "resolve",
  "hydrate",
  "skeleton",
]);

/**
 * Validates the options object passed to the @block decorator.
 * Checks for unknown keys and provides suggestions for typos.
 *
 * @param {string} name - The block name (for error messages).
 * @param {Object} options - The options object to validate.
 */
export function validateBlockOptions(name, options) {
  if (options && typeof options === "object") {
    const unknownKeys = Object.keys(options).filter(
      (key) => !VALID_BLOCK_OPTIONS.includes(key)
    );
    if (unknownKeys.length > 0) {
      const suggestions = unknownKeys
        .map((key) => formatWithSuggestion(key, VALID_BLOCK_OPTIONS))
        .join(", ");
      raiseBlockError(
        `@block("${name}"): unknown option(s): ${suggestions}. ` +
          `Valid options are: ${VALID_BLOCK_OPTIONS.join(", ")}.`
      );
    }
  }
}

/**
 * Validates and parses the block name.
 * Ensures the name follows the required format for core, plugin, or theme blocks.
 *
 * @param {string} name - The block name to validate.
 * @returns {import("discourse/lib/blocks/-internals/patterns").ParsedBlockName} Parsed name components.
 */
export function validateAndParseBlockName(name) {
  if (!VALID_NAMESPACED_BLOCK_PATTERN.test(name)) {
    raiseBlockError(
      `Block name "${name}" is invalid. ` +
        `Valid formats: "block-name" (core), "plugin:block-name" (plugin), ` +
        `"theme:namespace:block-name" (theme).`
    );
  }

  const parsed = parseBlockName(name);
  if (!parsed) {
    // This shouldn't happen if VALID_NAMESPACED_BLOCK_PATTERN passed, but be defensive
    raiseBlockError(`Block name "${name}" could not be parsed.`);
  }

  return parsed;
}

/**
 * Validates the optional display-metadata fields. None of these affect
 * runtime behaviour — they are pure presentation hints — so the checks here
 * are shallow type assertions rather than schema validation.
 *
 * @param {string} name - The block name (for error messages).
 * @param {Object} options - The decorator options object.
 */
export function validateDisplayMetadata(name, options) {
  const { displayName, icon, category, previewArgs, thumbnail } = options;

  for (const [key, value] of Object.entries({ displayName, icon, category })) {
    if (value == null) {
      continue;
    }
    if (typeof value !== "string" || value.trim() === "") {
      raiseBlockError(`Block "${name}": "${key}" must be a non-empty string.`);
    }
  }

  if (previewArgs != null) {
    const isPlainObject =
      typeof previewArgs === "object" &&
      !Array.isArray(previewArgs) &&
      Object.getPrototypeOf(previewArgs) === Object.prototype;
    if (!isPlainObject) {
      raiseBlockError(`Block "${name}": "previewArgs" must be a plain object.`);
    }
  }

  if (thumbnail != null && typeof thumbnail !== "string") {
    raiseBlockError(`Block "${name}": "thumbnail" must be a string.`);
  }
}

/**
 * Validates the optional `data` declaration (a block's coordinated data
 * dependency). `request` maps args to a serializable descriptor and `resolve`
 * turns a descriptor into render-ready data; both are required when `data` is
 * present. `hydrate` (server payload to render-ready data) and `skeleton`
 * (placeholder shape) are optional.
 *
 * @param {string} name - The block name (for error messages).
 * @param {Object|null|undefined} data - The decorator's `data` option.
 */
export function validateBlockDataOption(name, data) {
  if (data == null) {
    return;
  }

  if (typeof data !== "object" || Array.isArray(data)) {
    raiseBlockError(`Block "${name}": "data" must be an object.`);
  }

  const unknownKeys = Object.keys(data).filter(
    (key) => !VALID_DATA_KEYS.includes(key)
  );
  if (unknownKeys.length > 0) {
    const suggestions = unknownKeys
      .map((key) => formatWithSuggestion(key, VALID_DATA_KEYS))
      .join(", ");
    raiseBlockError(
      `Block "${name}": unknown "data" key(s): ${suggestions}. ` +
        `Valid keys are: ${VALID_DATA_KEYS.join(", ")}.`
    );
  }

  // `request` and `resolve` are the contract; without them the declaration
  // can't produce a descriptor or turn one into data.
  for (const key of ["request", "resolve"]) {
    if (typeof data[key] !== "function") {
      raiseBlockError(
        `Block "${name}": "data.${key}" is required and must be a function.`
      );
    }
  }

  for (const key of ["hydrate", "skeleton"]) {
    if (data[key] != null && typeof data[key] !== "function") {
      raiseBlockError(`Block "${name}": "data.${key}" must be a function.`);
    }
  }
}

/**
 * Validates outlet restriction patterns (allowedOutlets and deniedOutlets).
 * Checks for valid picomatch syntax and detects conflicts between patterns.
 *
 * @param {string} name - The block name (for error messages).
 * @param {string[]|null} allowedOutlets - Allowed outlet patterns.
 * @param {string[]|null} deniedOutlets - Denied outlet patterns.
 */
export function validateOutletRestrictions(
  name,
  allowedOutlets,
  deniedOutlets
) {
  // Validate outlet patterns are valid picomatch syntax (arrays of strings)
  validateOutletPatterns(allowedOutlets, name, "allowedOutlets");
  validateOutletPatterns(deniedOutlets, name, "deniedOutlets");

  // Detect conflicts between allowed and denied patterns.
  // This prevents configurations where a block is both allowed AND denied
  // in the same outlet, which would be confusing and likely a mistake.
  const conflict = detectPatternConflicts(allowedOutlets, deniedOutlets);
  if (conflict.conflict) {
    raiseBlockError(
      `Block "${name}": outlet "${conflict.details.outlet}" matches both ` +
        `allowedOutlets pattern "${conflict.details.allowed}" and ` +
        `deniedOutlets pattern "${conflict.details.denied}".`
    );
  }

  // Warn if patterns don't match any known outlet (possible typos).
  // This checks against both core outlets and custom outlets registered
  // by plugins/themes.
  warnUnknownOutletPatterns(allowedOutlets, name, "allowedOutlets");
  warnUnknownOutletPatterns(deniedOutlets, name, "deniedOutlets");
}
