import { DEBUG } from "@glimmer/env";

/**
 * Registry of available block outlet names in the application.
 * Block outlets provide extension points where plugins and themes can render custom block layouts.
 * Each outlet represents a specific location in the UI where blocks can be rendered.
 *
 * USE ONLY lowercase names
 *
 * @constant {ReadonlyArray<string>} BLOCK_OUTLETS - An immutable array of block outlet identifiers
 */
// eslint-discourse keep-array-sorted
export const BLOCK_OUTLETS = Object.freeze([
  "header-blocks",
  "hero-blocks",
  "homepage-blocks",
  "main-outlet-blocks",
  "sidebar-blocks",
]);

// Validate outlet names follow the lowercase convention.
BLOCK_OUTLETS.forEach((name) => {
  if (DEBUG) {
    if (name !== name.toLowerCase()) {
      throw new Error(`Block outlet name "${name}" must be lowercase.`);
    }
  }
});
