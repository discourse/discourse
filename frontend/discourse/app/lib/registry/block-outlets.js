import { DEBUG } from "@glimmer/env";
import { VALID_BLOCK_NAME_PATTERN } from "discourse/lib/blocks";

/**
 * Registry of CORE block outlet names in the application.
 *
 * Block outlets provide extension points where plugins and themes can render
 * custom block layouts. Each outlet represents a specific location in the UI
 * where blocks can be rendered.
 *
 * Outlet names must follow kebab-case: lowercase letters, numbers, and hyphens,
 * starting with a letter. Examples: "sidebar-blocks", "hero-blocks", "main-outlet-1"
 *
 * ## IMPORTANT: Plugin Outlets DO NOT Belong Here
 *
 * **This file is ONLY for core Discourse outlets that are always available.**
 *
 * If you are adding an outlet for a plugin (including core plugins like chat,
 * AI, polls, etc.), you MUST use the Plugin API instead:
 *
 * ```javascript
 * // In a pre-initializer
 * api.registerBlockOutlet("chat:message-actions", {
 *   description: "Actions below chat messages",
 * });
 * ```
 *
 * **Why?** Plugin outlets added here will cause issues because:
 * 1. The outlet will be "registered" even when the plugin is disabled
 * 2. Themes/plugins may try to render blocks to outlets that don't exist
 * 3. The outlet validation will pass but the actual rendering location won't exist
 *
 * **Rule of thumb:** If the outlet depends on ANY plugin being enabled, it MUST
 * be registered via `api.registerBlockOutlet()` in that plugin's code, not here.
 *
 * @constant {ReadonlyArray<string>} BLOCK_OUTLETS - An immutable array of core block outlet identifiers
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
