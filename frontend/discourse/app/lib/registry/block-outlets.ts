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
 * An immutable array of core block outlet identifiers.
 */
/** Display metadata recorded for a core block outlet. */
interface CoreOutletMetadata {
  /** Human-readable label for display purposes. */
  displayName: string;

  /** One-line summary of where the outlet renders. */
  description: string;

  /** Optional sub-grouping label (free-form, e.g. `"Layout"`). */
  category?: string;
}

/**
 * Display-metadata sidecar for the core outlets. Keys mirror `BLOCK_OUTLETS`;
 * consumers and other introspection tooling read this map via the blocks
 * service's outlet metadata listing.
 *
 * Splitting the metadata from `BLOCK_OUTLETS` keeps the array a pure list of
 * names (back-compat for `.includes(name)` consumers) while letting us
 * surface display-friendly fields without a breaking schema change.
 *
 * Adding a new core outlet here? Add the name to `BLOCK_OUTLETS` AND a
 * matching entry below. The DEBUG block at the bottom fails the boot if
 * the two diverge.
 */
export const CORE_OUTLET_METADATA: Readonly<
  Record<string, Readonly<CoreOutletMetadata>>
> = Object.freeze({
  "hero-blocks": Object.freeze({
    displayName: "Hero",
    description: "The page-level hero area above the main content.",
  }),
  "homepage-blocks": Object.freeze({
    displayName: "Homepage",
    description: "The main content area of the site homepage.",
  }),
  "main-outlet-blocks": Object.freeze({
    displayName: "Main outlet",
    description: "The primary content area shared across most pages.",
  }),
  "sidebar-blocks": Object.freeze({
    displayName: "Sidebar",
    description: "The site-wide sidebar.",
  }),
  "sidebar-discovery": Object.freeze({
    displayName: "Sidebar (discovery)",
    description: "The sidebar slot for topic-discovery pages.",
  }),
});

// eslint-discourse keep-array-sorted
export const BLOCK_OUTLETS = Object.freeze([
  "hero-blocks",
  "homepage-blocks",
  "main-outlet-blocks",
  "sidebar-blocks",
  "sidebar-discovery",
]);

// Validate outlet names follow the kebab-case pattern and that
// `CORE_OUTLET_METADATA` stays in sync with `BLOCK_OUTLETS`.
if (DEBUG) {
  BLOCK_OUTLETS.forEach((name) => {
    if (!VALID_BLOCK_NAME_PATTERN.test(name)) {
      throw new Error(
        `Block outlet name "${name}" is invalid. ` +
          `Names must be kebab-case: lowercase letters, numbers, and hyphens, starting with a letter.`
      );
    }
    if (!CORE_OUTLET_METADATA[name]) {
      throw new Error(
        `Block outlet "${name}" is missing an entry in CORE_OUTLET_METADATA.`
      );
    }
  });
  Object.keys(CORE_OUTLET_METADATA).forEach((name) => {
    if (!BLOCK_OUTLETS.includes(name)) {
      throw new Error(
        `CORE_OUTLET_METADATA has entry for "${name}" but it isn't in BLOCK_OUTLETS.`
      );
    }
  });
}
