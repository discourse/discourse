import { DEBUG } from "@glimmer/env";

// eslint-discourse keep-array-sorted
export const BLOCK_OUTLETS = Object.freeze([
  "header-blocks",
  "hero-blocks",
  "homepage-blocks",
  "main-outlet-blocks",
  "sidebar-blocks",
]);

// Performing checks in the blocks registry
BLOCK_OUTLETS.forEach((name) => {
  if (DEBUG) {
    if (name !== name.toLowerCase()) {
      throw new Error(`Block outlet name "${name}" must be lowercase.`);
    }
  }
});
