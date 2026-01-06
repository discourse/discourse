/**
 * Pattern constants for block name validation.
 *
 * @module discourse/lib/blocks/patterns
 */

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
 * Parses a full block name into its components.
 *
 * @param {string} fullName - The full block name.
 * @returns {{ type: "core"|"plugin"|"theme", namespace: string|null, name: string }|null}
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
