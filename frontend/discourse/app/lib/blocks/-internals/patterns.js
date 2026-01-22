// @ts-check
/**
 * Pattern constants for block name validation.
 *
 * @module discourse/lib/blocks/-internals/patterns
 */

/**
 * Maximum allowed nesting depth for block layouts.
 *
 * Prevents stack overflow from deeply nested configurations. This limit is
 * enforced at layout validation time with a clear error message, and as a
 * defense-in-depth measure during ghost component rendering.
 *
 * A depth of 20 is generous for real-world use cases while protecting against
 * malicious or buggy configurations that could cause infinite recursion.
 *
 * @type {number}
 */
export const MAX_LAYOUT_DEPTH = 20;

/**
 * Maximum allowed length for block names.
 *
 * Prevents potential memory and performance issues from extremely long names.
 * A limit of 100 characters is generous for real-world use cases while
 * protecting against malicious or buggy configurations.
 *
 * This applies to the full namespaced name (e.g., "theme:my-theme:my-block").
 *
 * @type {number}
 */
export const MAX_BLOCK_NAME_LENGTH = 100;

/**
 * Symbol used to mark a block reference as optional and missing from the registry.
 * When this marker is returned from resolution functions, it signals that the block
 * should be silently skipped rather than throwing an error.
 *
 * Used in layout validation and block registration to identify optional
 * blocks that aren't registered and should be skipped during validation and rendering.
 *
 * @type {symbol}
 */
export const OPTIONAL_MISSING = Symbol("optional-missing");

/**
 * Valid block name pattern: lowercase letters, numbers, and hyphens.
 * Must start with a letter. Examples: "hero-banner", "sidebar-blocks", "my-block-1"
 *
 * Used for both block names and outlet names since they follow the same format.
 */
export const VALID_BLOCK_NAME_PATTERN = /^[a-z][a-z0-9-]*$/;

/**
 * Valid namespaced block name pattern. Supports three formats:
 *
 * - **Core blocks**: `block-name` (no prefix)
 * - **Plugin blocks**: `plugin-name:block-name` (where plugin-name is not "theme")
 * - **Theme blocks**: `theme:theme-name:block-name`
 *
 * Each segment must start with a letter and contain only lowercase letters,
 * numbers, and hyphens.
 *
 * @example
 * // Valid patterns:
 * "group"                      // Core block
 * "chat:message-widget"        // Plugin block
 * "theme:tactile:hero-banner"  // Theme block
 *
 * // Invalid patterns:
 * "Theme:Name:block"           // Uppercase not allowed
 * "theme:block"                // Theme requires namespace segment
 * "my_block"                   // Underscores not allowed
 */
export const VALID_NAMESPACED_BLOCK_PATTERN =
  /^(?:theme:[a-z][a-z0-9-]*:[a-z][a-z0-9-]*|(?!theme:)[a-z][a-z0-9-]*:[a-z][a-z0-9-]*|[a-z][a-z0-9-]*)$/;

/**
 * The parsed components of a block name.
 *
 * @typedef {{
 *   type: "core"|"plugin"|"theme",
 *   namespace: string|null,
 *   name: string
 * }} ParsedBlockName
 */

/**
 * Parses a full block name into its components.
 *
 * @param {string} fullName - The full block name.
 * @returns {ParsedBlockName|null}
 *   An object with the parsed components, or `null` if the name is invalid.
 *
 * @example
 * parseBlockName("group")
 * // => { type: "core", namespace: null, name: "group" }
 *
 * parseBlockName("chat:message-widget")
 * // => { type: "plugin", namespace: "chat", name: "message-widget" }
 *
 * parseBlockName("theme:tactile:hero-banner")
 * // => { type: "theme", namespace: "tactile", name: "hero-banner" }
 *
 * parseBlockName("Invalid_Name")
 * // => null
 */
export function parseBlockName(fullName) {
  // Theme: theme:namespace:name
  const themeMatch = fullName.match(
    /^theme:([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)$/
  );
  if (themeMatch) {
    return { type: "theme", namespace: themeMatch[1], name: themeMatch[2] };
  }

  // Plugin: namespace:name (where namespace is NOT "theme")
  const pluginMatch = fullName.match(/^([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)$/);
  if (pluginMatch && pluginMatch[1] !== "theme") {
    return { type: "plugin", namespace: pluginMatch[1], name: pluginMatch[2] };
  }

  // Core: just name
  const coreMatch = fullName.match(/^[a-z][a-z0-9-]*$/);
  if (coreMatch) {
    return { type: "core", namespace: null, name: fullName };
  }

  return null;
}

/**
 * Parses a block reference string to extract the block name and optional flag.
 *
 * Block references can be marked as optional by appending a `?` suffix to the
 * name. Optional blocks that are not registered will be silently skipped
 * instead of throwing an error.
 *
 * Supports all namespaced formats:
 * - Core: `"block-name"` or `"block-name?"`
 * - Plugin: `"plugin:block"` or `"plugin:block?"`
 * - Theme: `"theme:namespace:block"` or `"theme:namespace:block?"`
 *
 * @param {string|Object} blockRef - The block reference. If a string, may have an
 *   optional `?` suffix. Non-string references (e.g., component classes) are
 *   returned as-is in the `name` property with `optional: false`.
 * @returns {{ name: string|Object, optional: boolean }} Parsed result with the clean
 *   block name (or original reference) and whether it's optional.
 *
 * @example
 * parseBlockReference("chat:widget?")
 * // => { name: "chat:widget", optional: true }
 *
 * parseBlockReference("hero-banner")
 * // => { name: "hero-banner", optional: false }
 */
export function parseBlockReference(blockRef) {
  if (typeof blockRef === "string" && blockRef.endsWith("?")) {
    return { name: blockRef.slice(0, -1), optional: true };
  }
  return { name: blockRef, optional: false };
}
