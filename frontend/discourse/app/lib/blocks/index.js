// @ts-check
/**
 * Public API for the Discourse Block system.
 *
 * This module exposes constants and utilities that plugin and theme developers
 * can use when working with blocks. Internal implementation details are kept
 * in the `-internals/` directory and should not be imported directly.
 *
 * @module discourse/lib/blocks
 *
 * @example
 * import {
 *   VALID_BLOCK_NAME_PATTERN,
 *   parseBlockName,
 *   VALID_ARG_TYPES,
 *   matchValue,
 * } from "discourse/lib/blocks";
 */

/* Pattern Validation */

/**
 * Valid block name pattern: lowercase letters, numbers, and hyphens.
 * Must start with a letter. Examples: "hero-banner", "sidebar-blocks", "my-block-1"
 *
 * Used for both block names and outlet names since they follow the same format.
 */
export { VALID_BLOCK_NAME_PATTERN } from "discourse/lib/blocks/-internals/patterns";

/**
 * Valid namespaced block name pattern. Supports three formats:
 *
 * - **Core blocks**: `block-name` (no prefix)
 * - **Plugin blocks**: `plugin-name:block-name` (where plugin-name is not "theme")
 * - **Theme blocks**: `theme:theme-name:block-name`
 *
 * @example
 * // Valid patterns:
 * "group"                      // Core block
 * "chat:message-widget"        // Plugin block
 * "theme:tactile:hero-banner"  // Theme block
 */
export { VALID_NAMESPACED_BLOCK_PATTERN } from "discourse/lib/blocks/-internals/patterns";

/**
 * Parses a full block name into its components.
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
 */
export { parseBlockName } from "discourse/lib/blocks/-internals/patterns";

/**
 * Parses a block reference string to extract the block name and optional flag.
 *
 * Block references can be marked as optional by appending a `?` suffix to the
 * name. Optional blocks that are not registered will be silently skipped
 * instead of throwing an error.
 *
 * @example
 * parseBlockReference("chat:widget?")
 * // => { name: "chat:widget", optional: true }
 *
 * parseBlockReference("hero-banner")
 * // => { name: "hero-banner", optional: false }
 */
export { parseBlockReference } from "discourse/lib/blocks/-internals/patterns";

/* Arg Schema Constants */

/**
 * Valid arg types for schema definitions.
 * Types: "string", "number", "boolean", "array", "any"
 */
export { VALID_ARG_TYPES } from "discourse/lib/blocks/-internals/validation/args";

/**
 * Valid item types for array args.
 * Types: "string", "number", "boolean"
 */
export { VALID_ITEM_TYPES } from "discourse/lib/blocks/-internals/validation/args";

/* Constraint Types */

/**
 * Valid constraint types for cross-arg validation.
 * Types: "atLeastOne", "exactlyOne", "allOrNone", "atMostOne", "requires"
 */
export { VALID_CONSTRAINT_TYPES } from "discourse/lib/blocks/-internals/validation/constraints";

/* Page Types (for Route Condition) */

/**
 * Array of all valid page type names for the route condition.
 * Types: "CATEGORY_PAGES", "TAG_PAGES", "DISCOVERY_PAGES", "HOMEPAGE",
 *        "TOP_MENU", "TOPIC_PAGES", "USER_PAGES", "ADMIN_PAGES", "GROUP_PAGES"
 */
export { VALID_PAGE_TYPES } from "discourse/lib/blocks/-internals/matching/page-definitions";

/* Utilities for Custom Conditions */

/**
 * Retrieves a value from a nested object using dot-notation path.
 *
 * This utility safely navigates through nested object properties using a
 * dot-separated path string. It handles null/undefined values gracefully
 * at any level of the path.
 *
 * @example
 * const user = { profile: { name: "Alice", settings: { theme: "dark" } } };
 * getByPath(user, "profile.name"); // "Alice"
 * getByPath(user, "profile.settings.theme"); // "dark"
 * getByPath(user, "profile.missing"); // undefined
 */
export { getByPath } from "discourse/lib/blocks/-internals/utils";

/**
 * Evaluates a value matcher spec against an actual value.
 * Supports the same AND/OR/NOT logic as condition evaluation.
 *
 * Supports:
 * - Exact match: `123`, `"foo"`
 * - Array of values (OR): `[123, 456]` matches if actual is any of these
 * - RegExp: `/^foo/` matches if actual matches the pattern
 * - NOT: `{ not: value }` matches if actual does NOT match value
 * - ANY (OR): `{ any: [...] }` matches if actual matches any spec in array
 *
 * @example
 * matchValue({ actual: 5, expected: 5 }) // true
 * matchValue({ actual: 5, expected: [3, 5, 7] }) // true (OR)
 * matchValue({ actual: "hello", expected: /^hel/ }) // true
 * matchValue({ actual: 5, expected: { not: 3 } }) // true
 */
export { matchValue } from "discourse/lib/blocks/-internals/matching/value-matcher";
