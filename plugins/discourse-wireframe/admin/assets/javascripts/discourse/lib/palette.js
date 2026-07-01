// @ts-check
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";

/**
 * Builds the editor's block palette: every registered block, filtered
 * to those the author can pick (`paletteHidden !== true`) and sorted by
 * displayName.
 *
 * This is the single source of truth for the palette shape. Every face of
 * the palette consumes it — the sidebar panel, the empty-state placeholder
 * popover (outlet root, empty container, slot, grid cell), and the
 * quick-inserter — so they list the same blocks with the same metadata.
 * Sorting is by displayName only; callers that group (the sidebar's
 * category sections) or re-order (the inserter's curated-first suggestions)
 * layer their own ordering on top, and within any such group the
 * displayName order is preserved.
 *
 * `description` and `namespaceType` are read off the raw block metadata
 * (they're not part of the resolved display metadata); `thumbnail` is the
 * optional preview a block may declare — a URL string or an inline SVG
 * component (`null` when it doesn't, in which case the tile falls back to a
 * default placeholder).
 *
 * @param {*} blocksService - The `blocks` service (`@service blocks`).
 *   Must expose `listBlocksWithMetadata()` returning `{name, component,
 *   metadata}[]`.
 * @returns {Array<{name: string, displayName: string, icon: string,
 *   category: string, description: string, namespaceType: string,
 *   thumbnail: ((string|Function|Object)|null), paletteHidden: boolean}>}
 */
export function buildBlockPalette(blocksService) {
  return blocksService
    .listBlocksWithMetadata()
    .map(({ name, component, metadata }) => {
      const display = getBlockDisplayMetadata(component) ?? {};
      return {
        name,
        displayName: display.displayName,
        icon: display.icon,
        category: display.category ?? "Misc",
        description: metadata?.description ?? "",
        namespaceType: metadata?.namespaceType ?? "core",
        thumbnail: display.thumbnail ?? null,
        paletteHidden: display.paletteHidden === true,
      };
    })
    .filter((row) => !row.paletteHidden)
    .sort((a, b) => a.displayName.localeCompare(b.displayName));
}
