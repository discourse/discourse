// @ts-check
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";

/**
 * Builds the editor's block palette: every registered block, filtered
 * to those the author can pick (`paletteHidden !== true`) and sorted
 * by category then displayName.
 *
 * Same data the canvas drag-palette renders, reused by every empty-state
 * placeholder popover (outlet root, empty container, slot, grid cell)
 * so the four contexts list the same options in the same order.
 *
 * @param {*} blocksService - The `blocks` service (`@service blocks`).
 *   Must expose `listBlocksWithMetadata()` returning `{name, component}[]`.
 * @returns {Array<{name: string, displayName: string, icon: string,
 *   category: string, paletteHidden: boolean}>}
 */
export function buildBlockPalette(blocksService) {
  return blocksService
    .listBlocksWithMetadata()
    .map(({ name, component }) => {
      const display = getBlockDisplayMetadata(component) ?? {};
      return {
        name,
        displayName: display.displayName,
        icon: display.icon,
        category: display.category ?? "Misc",
        paletteHidden: display.paletteHidden === true,
      };
    })
    .filter((row) => !row.paletteHidden)
    .sort(
      (a, b) =>
        a.category.localeCompare(b.category) ||
        a.displayName.localeCompare(b.displayName)
    );
}
