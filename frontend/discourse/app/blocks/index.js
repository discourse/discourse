/**
 * Export hub for core block components.
 *
 * This module is imported by the Blocks service to auto-discover
 * built-in block components. All exports must be @block-decorated
 * component classes.
 *
 * Theme/plugin blocks are registered separately via `api.registerBlock()`
 * in pre-initializers.
 *
 * @module discourse/blocks
 */
export { default as BlockGroup } from "discourse/blocks/block-group";
