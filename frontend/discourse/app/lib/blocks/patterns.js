/**
 * Pattern constants for block name validation.
 *
 * @module discourse/lib/blocks/patterns
 */

/**
 * Valid block name pattern: lowercase letters, numbers, and hyphens.
 * Must start with a letter. Examples: "hero-banner", "my-block-1"
 */
export const VALID_BLOCK_NAME_PATTERN = /^[a-z][a-z0-9-]*$/;
