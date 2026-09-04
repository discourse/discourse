/**
 * Block Decorator Validation
 *
 * This module contains validation functions used by the `@block` decorator.
 * These validations run at decoration time (not render time) for fail-fast behavior.
 */
import { DEBUG } from "@glimmer/env";
import { BLOCK_CATEGORIES, type BlockOptions } from "discourse/blocks/types";
import { isBlockDataSource } from "discourse/lib/blocks/-internals/data-source";
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
  "paletteVariants",
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

const VALID_PALETTE_VARIANT_KEYS = Object.freeze([
  "id",
  "displayName",
  "description",
  "defaultArgs",
  "thumbnail",
]);

const VALID_PALETTE_VARIANT_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

/**
 * Valid keys for the `data` option (a block's declared data dependency).
 */
const VALID_DATA_KEYS = Object.freeze([
  "request",
  "source",
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

  // A group outside the known set is not an error: the block still renders and
  // is listed under the catch-all. Say so while developing, since the author
  // almost certainly meant one of the real groups.
  if (
    DEBUG &&
    category != null &&
    !(BLOCK_CATEGORIES as readonly string[]).includes(category)
  ) {
    // eslint-disable-next-line no-console
    console.warn(
      `[Blocks] Block "${name}": unknown category "${category}"; expected one of ${BLOCK_CATEGORIES.join(", ")}. It will be listed as uncategorized.`
    );
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

  validateThumbnail(name, "thumbnail", thumbnail);
}

/** Validates named starting configurations exposed by block-selection tools. */
export function validatePaletteVariants(
  name: string,
  variants: BlockOptions["paletteVariants"]
): void {
  if (variants == null) {
    return;
  }
  if (!Array.isArray(variants) || variants.length === 0) {
    raiseBlockError(
      `Block "${name}": "paletteVariants" must be a non-empty array.`
    );
  }

  const ids = new Set<string>();
  for (const [index, variant] of variants.entries()) {
    const path = `paletteVariants[${index}]`;
    if (
      typeof variant !== "object" ||
      variant === null ||
      Array.isArray(variant)
    ) {
      raiseBlockError(`Block "${name}": "${path}" must be an object.`);
    }

    const unknownKeys = Object.keys(variant).filter(
      (key) => !VALID_PALETTE_VARIANT_KEYS.includes(key)
    );
    if (unknownKeys.length > 0) {
      raiseBlockError(
        `Block "${name}": unknown "${path}" key(s): ${unknownKeys.join(", ")}.`
      );
    }
    if (!VALID_PALETTE_VARIANT_ID_PATTERN.test(variant.id)) {
      raiseBlockError(
        `Block "${name}": "${path}.id" must be a kebab-case identifier.`
      );
    }
    if (ids.has(variant.id)) {
      raiseBlockError(
        `Block "${name}": "paletteVariants" has duplicate id "${variant.id}".`
      );
    }
    ids.add(variant.id);

    if (
      typeof variant.displayName !== "string" ||
      variant.displayName.trim() === ""
    ) {
      raiseBlockError(
        `Block "${name}": "${path}.displayName" must be a non-empty string.`
      );
    }
    if (
      variant.description != null &&
      (typeof variant.description !== "string" ||
        variant.description.trim() === "")
    ) {
      raiseBlockError(
        `Block "${name}": "${path}.description" must be a non-empty string.`
      );
    }
    if (
      variant.defaultArgs != null &&
      !isPlainPaletteArgs(variant.defaultArgs)
    ) {
      raiseBlockError(
        `Block "${name}": "${path}.defaultArgs" must be a plain object.`
      );
    }
    validateThumbnail(name, `${path}.thumbnail`, variant.thumbnail);
  }
}

function isPlainPaletteArgs(value: unknown): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype
  );
}

function validateThumbnail(name: string, path: string, thumbnail: unknown) {
  if (thumbnail == null) {
    return;
  }
  const isUrl = typeof thumbnail === "string" && thumbnail.trim() !== "";
  const isLightDark =
    typeof thumbnail === "object" && thumbnail !== null && "light" in thumbnail;
  const isLazyLoader =
    typeof thumbnail === "function" && !isComponent(thumbnail);
  if (!isUrl && !isLightDark && !isComponent(thumbnail) && !isLazyLoader) {
    raiseBlockError(
      `Block "${name}": "${path}" must be a non-empty URL string, a { light, dark } pair of URLs, an inline SVG component, or a loader that resolves to one (e.g. () => import(...)).`
    );
  }
}

/**
 * Validates the optional `data` declaration (a block's coordinated data
 * dependency). `request` maps args to a serializable descriptor and is always
 * required. Every declaration must select a data source created with
 * `defineBlockDataSource`; resolution and hydration belong to that source and
 * cannot be declared inline. `skeleton` remains an optional per-block
 * presentation hint.
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

  if (typeof data.request !== "function") {
    raiseBlockError(
      `Block "${name}": "data.request" is required and must be a function.`
    );
  }

  for (const key of ["resolve", "hydrate"]) {
    if (Object.hasOwn(data, key)) {
      raiseBlockError(
        `Block "${name}": "data.${key}" must be declared on the block's data source, not inline.`
      );
    }
  }

  if (!Object.hasOwn(data, "source")) {
    raiseBlockError(
      `Block "${name}": "data.source" is required and must be created with defineBlockDataSource().`
    );
  }

  if (!isBlockDataSource(data.source)) {
    raiseBlockError(
      `Block "${name}": "data.source" must be a data source created with defineBlockDataSource.`
    );
  }

  if (data.skeleton != null && typeof data.skeleton !== "function") {
    raiseBlockError(`Block "${name}": "data.skeleton" must be a function.`);
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
