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
  "containerClassNames",
  "description",
  "args",
  "childArgs",
  "constraints",
  "validate",
  "allowedOutlets",
  "deniedOutlets",
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
