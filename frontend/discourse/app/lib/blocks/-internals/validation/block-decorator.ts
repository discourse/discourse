/**
 * Block Decorator Validation
 *
 * This module contains validation functions used by the `@block` decorator.
 * These validations run at decoration time (not render time) for fail-fast behavior.
 */
import type { BlockOptions } from "discourse/blocks/types";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";
import {
  detectPatternConflicts,
  validateOutletPatterns,
  warnUnknownOutletPatterns,
} from "discourse/lib/blocks/-internals/matching/outlet-matcher";
import {
  parseBlockName,
  type ParsedBlockName,
  VALID_NAMESPACED_BLOCK_PATTERN,
} from "discourse/lib/blocks/-internals/patterns";
import isComponent from "discourse/lib/is-component";
import { formatWithSuggestion } from "discourse/lib/string-similarity";

/**
 * Valid keys for the `@block` decorator options (block schema).
 */
export const VALID_BLOCK_OPTIONS: readonly string[] = Object.freeze([
  "container",
  "classNames",
  "description",
  "args",
  "childArgs",
  "childBlocks",
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
  "gridEditable",
  "data",
  "parts",
]);

/**
 * Valid keys for a single entry in the `parts` option (one inner block of a
 * code-defined composition).
 */
const VALID_PART_KEYS = Object.freeze(["id", "block", "args", "lock"]);

/**
 * Valid keys for the `data` option (a block's declared data dependency).
 */
const VALID_DATA_KEYS = Object.freeze([
  "request",
  "resolve",
  "hydrate",
  "skeleton",
]);

/**
 * Validates the options object passed to the `@block` decorator.
 * Checks for unknown keys and provides suggestions for typos.
 *
 * @param name - The block name (for error messages).
 * @param options - The options object to validate.
 */
export function validateBlockOptions(
  name: string,
  options: BlockOptions
): void {
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
 * @param name - The block name to validate.
 * @returns Parsed name components.
 */
export function validateAndParseBlockName(name: string): ParsedBlockName {
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
 * @param name - The block name (for error messages).
 * @param options - The decorator options object.
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

  if (thumbnail != null) {
    // A thumbnail is one of four forms:
    // - a non-empty URL string (rendered through an `<img>`);
    // - a `{ light, dark }` pair of URLs (rendered through `DLightDarkImg`);
    // - a component reference (an inline SVG component), rendered inline so it
    //   can use theme color tokens;
    // - a loader function that resolves to such a component (a lazily-loaded
    //   thumbnail, e.g. `() => import("...")`), so the component stays out of
    //   any bundle that never renders the thumbnail.
    // `isComponent` positively identifies a real component (class or
    // template-only), so anything else is rejected here at decoration time.
    const isUrl = typeof thumbnail === "string" && thumbnail.trim() !== "";
    // A `{ light, dark }` pair must carry `light` (the default source); `dark`
    // alone is invalid.
    const isLightDark =
      typeof thumbnail === "object" &&
      thumbnail !== null &&
      "light" in thumbnail;
    // A component class is itself a function, so a lazy loader is any function
    // that is not already a renderable component.
    const isLazyLoader =
      typeof thumbnail === "function" && !isComponent(thumbnail);
    if (!isUrl && !isLightDark && !isComponent(thumbnail) && !isLazyLoader) {
      raiseBlockError(
        `Block "${name}": "thumbnail" must be a non-empty URL string, a { light, dark } pair of URLs, an inline SVG component, or a loader that resolves to one (e.g. () => import(...)).`
      );
    }
  }
}

/**
 * Validates the optional `data` declaration (a block's coordinated data
 * dependency). `request` maps args to a serializable descriptor and `resolve`
 * turns a descriptor into render-ready data; both are required when `data` is
 * present. `hydrate` (server payload to render-ready data) and `skeleton`
 * (placeholder shape) are optional.
 *
 * @param name - The block name (for error messages).
 * @param data - The decorator's `data` option.
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
 * Validates the optional `parts` declaration: a block's code-defined inner
 * composition. Each part names an inner block (by registry name or class
 * reference), carries default `args`, and is addressed by a stable, unique
 * `id`. A part may mark args as locked (`lock`) so instances can't override
 * them in place. Validation is structural and runs at decoration time for
 * fail-fast behaviour; inner-block resolution happens lazily at render.
 *
 * @param name - The block name (for error messages).
 * @param parts - The decorator's `parts` option.
 */
export function validateBlockParts(name, parts) {
  if (parts == null) {
    return;
  }

  if (!Array.isArray(parts) || parts.length === 0) {
    raiseBlockError(`Block "${name}": "parts" must be a non-empty array.`);
  }

  const seenIds = new Set();
  parts.forEach((part, index) => {
    const isPlainObject =
      part != null && typeof part === "object" && !Array.isArray(part);
    if (!isPlainObject) {
      raiseBlockError(
        `Block "${name}": parts[${index}] must be an object with "id" and "block".`
      );
    }

    const unknownKeys = Object.keys(part).filter(
      (key) => !VALID_PART_KEYS.includes(key)
    );
    if (unknownKeys.length > 0) {
      const suggestions = unknownKeys
        .map((key) => formatWithSuggestion(key, VALID_PART_KEYS))
        .join(", ");
      raiseBlockError(
        `Block "${name}": parts[${index}] has unknown key(s): ${suggestions}. ` +
          `Valid keys are: ${VALID_PART_KEYS.join(", ")}.`
      );
    }

    if (typeof part.id !== "string" || part.id.trim() === "") {
      raiseBlockError(
        `Block "${name}": parts[${index}] requires a non-empty string "id".`
      );
    }

    // The id becomes a segment of a dot-delimited override path
    // (e.g. `action.label`), so it must not contain the path separator.
    if (part.id.includes(".")) {
      raiseBlockError(
        `Block "${name}": part id "${part.id}" must not contain a "." ` +
          `(ids are joined with "." to address nested parts).`
      );
    }

    if (seenIds.has(part.id)) {
      raiseBlockError(
        `Block "${name}": duplicate part id "${part.id}". Part ids must be unique.`
      );
    }
    seenIds.add(part.id);

    const blockRef = part.block;
    if (
      blockRef == null ||
      (typeof blockRef !== "string" && typeof blockRef !== "function")
    ) {
      raiseBlockError(
        `Block "${name}": parts[${index}] ("${part.id}") requires a "block" ` +
          `(a registered block name or a block class).`
      );
    }
    if (typeof blockRef === "string" && blockRef.trim() === "") {
      raiseBlockError(
        `Block "${name}": parts[${index}] ("${part.id}") has an empty "block" name.`
      );
    }

    if (part.args != null) {
      const argsIsPlainObject =
        typeof part.args === "object" && !Array.isArray(part.args);
      if (!argsIsPlainObject) {
        raiseBlockError(
          `Block "${name}": parts[${index}] ("${part.id}") "args" must be a plain object.`
        );
      }
    }

    // `lock` is either `true` (the whole part is locked) or a list of arg
    // names that can't be overridden in place.
    if (part.lock != null && part.lock !== true) {
      const lockIsStringArray =
        Array.isArray(part.lock) &&
        part.lock.every((arg) => typeof arg === "string");
      if (!lockIsStringArray) {
        raiseBlockError(
          `Block "${name}": parts[${index}] ("${part.id}") "lock" must be ` +
            `true or an array of arg-name strings.`
        );
      }
    }
  });
}

/**
 * Validates outlet restriction patterns (allowedOutlets and deniedOutlets).
 * Checks for valid picomatch syntax and detects conflicts between patterns.
 *
 * @param name - The block name (for error messages).
 * @param allowedOutlets - Allowed outlet patterns.
 * @param deniedOutlets - Denied outlet patterns.
 */
export function validateOutletRestrictions(
  name: string,
  allowedOutlets: string[] | null | undefined,
  deniedOutlets: string[] | null | undefined
): void {
  // Validate outlet patterns are valid picomatch syntax (arrays of strings)
  validateOutletPatterns(allowedOutlets, name, "allowedOutlets");
  validateOutletPatterns(deniedOutlets, name, "deniedOutlets");

  // Detect conflicts between allowed and denied patterns.
  // This prevents configurations where a block is both allowed AND denied
  // in the same outlet, which would be confusing and likely a mistake.
  const conflict = detectPatternConflicts(allowedOutlets, deniedOutlets);
  if (conflict.conflict && conflict.details) {
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

/**
 * Validates the `childBlocks` option — the allow-list of block names a
 * container may hold as direct children. Only valid on containers, and every
 * entry must be a non-empty, well-formed block name.
 *
 * @param name - The block name (for error messages).
 * @param childBlocks - The declared allow-list, or null.
 * @param isContainer - Whether the decorated block is a container.
 */
export function validateChildBlocks(name, childBlocks, isContainer) {
  if (childBlocks == null) {
    return;
  }
  if (!isContainer) {
    raiseBlockError(
      `Block "${name}": "childBlocks" is only valid for container blocks (container: true).`
    );
  }
  if (!Array.isArray(childBlocks) || childBlocks.length === 0) {
    raiseBlockError(
      `Block "${name}": "childBlocks" must be a non-empty array of block names.`
    );
  }
  for (const childName of childBlocks) {
    if (
      typeof childName !== "string" ||
      !VALID_NAMESPACED_BLOCK_PATTERN.test(childName)
    ) {
      raiseBlockError(
        `Block "${name}": "childBlocks" entry "${childName}" is not a valid block name.`
      );
    }
  }
}
