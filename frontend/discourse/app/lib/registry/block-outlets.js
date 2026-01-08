import { DEBUG } from "@glimmer/env";
import { VALID_BLOCK_NAME_PATTERN } from "discourse/lib/blocks/patterns";

/**
 * Registry of available block outlet names in the application.
 * Block outlets provide extension points where plugins and themes can render custom block layouts.
 * Each outlet represents a specific location in the UI where blocks can be rendered.
 *
 * Outlet names must follow kebab-case: lowercase letters, numbers, and hyphens,
 * starting with a letter. Examples: "sidebar-blocks", "hero-blocks", "main-outlet-1"
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

// Validate outlet names follow the kebab-case pattern.
if (DEBUG) {
  BLOCK_OUTLETS.forEach((name) => {
    if (!VALID_BLOCK_NAME_PATTERN.test(name)) {
      throw new Error(
        `Block outlet name "${name}" is invalid. ` +
          `Names must be kebab-case: lowercase letters, numbers, and hyphens, starting with a letter.`
      );
    }
  });
}
