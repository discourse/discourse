import type { LayoutEntry } from "discourse/blocks/types";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

/** A layout entry carrying the editor's stable identity token. */
export type KeyedLayoutEntry = {
  /** The block reference used to resolve the block name. */
  block: LayoutEntry["block"];

  /** The stable token assigned when the editor loads the entry. */
  __stableKey?: string | number;
};

/**
 * Resolves a layout entry's `block` reference to the same composite key the
 * BLOCK_DEBUG callback receives (`${blockName}:${__stableKey}`).
 *
 * Lives in its own file (universal bundle) so both `lib/grid-math.ts`
 * (universal — `parsePlacement` is called from the live-page
 * `wf-layout.gjs` block) and `lib/mutate-layout.ts` (admin-only) can
 * read it without pulling mutate-layout's editor-only helpers into the
 * universal bundle.
 *
 * @param entry - The layout entry whose composite key should be resolved.
 * @returns The composite block key, or `null` before stable identity exists.
 */
export function entryKey(entry: KeyedLayoutEntry): string | null {
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
