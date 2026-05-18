// @ts-check
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

/**
 * Resolves a layout entry's `block` reference to the same composite key the
 * BLOCK_DEBUG callback receives (`${blockName}:${__stableKey}`).
 *
 * Lives in its own file (universal bundle) so both `lib/grid-math.js`
 * (universal — `parsePlacement` is called from the live-page
 * `ve-layout.gjs` block) and `lib/mutate-layout.js` (now admin-bundle)
 * can read it without dragging mutate-layout's editor-only helpers
 * into the universal bundle. Before the extraction, grid-math imported
 * entryKey directly from mutate-layout, which would have prevented
 * shipping mutate-layout to the admin-only bundle.
 *
 * @param {Object} entry
 * @returns {string|null}
 */
export function entryKey(entry) {
  if (entry?.__stableKey === undefined) {
    return null;
  }
  const blockRef = entry.block;
  if (typeof blockRef === "string") {
    return `${blockRef}:${entry.__stableKey}`;
  }
  const name = getBlockMetadata(blockRef)?.blockName;
  if (!name) {
    return null;
  }
  return `${name}:${entry.__stableKey}`;
}
