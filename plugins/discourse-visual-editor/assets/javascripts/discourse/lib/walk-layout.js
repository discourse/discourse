// @ts-check
/**
 * Walks the registered block-outlet layouts and returns a tree-flattened
 * structure suitable for rendering the read-only outline panel.
 *
 * The return value groups rows by outlet:
 *
 *   [
 *     { outletName: "homepage-blocks", rows: [<row>, <row>, ...] },
 *     { outletName: "sidebar-blocks",  rows: [<row>, ...] },
 *     ...
 *   ]
 *
 * Each row carries `{ depth, blockName, blockId, blockKey, args, conditions,
 * hasChildren, path }`, where:
 *   - `depth` is the nesting level inside the outlet (0 for top-level).
 *   - `blockKey` is `${blockName}:${entry.__stableKey}`, matching the key
 *     minted by `entry-processing.js` and exposed via the BLOCK_DEBUG
 *     payload. Outline ↔ canvas selection compares against this.
 *   - `path` is the array index trail (e.g. `[0, "children", 1]`) suitable
 *     for re-locating the entry from the layout root in future phases that
 *     mutate layouts.
 *
 * Phase 1 limitation: walks every outlet that `services/blocks` reports as
 * having a layout, regardless of whether a `<BlockOutlet>` is actually
 * mounted on the current page. Multi-outlet awareness with proper mount
 * tracking ships in Phase 6.
 */
import { _getOutletLayouts } from "discourse/blocks/block-outlet";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

/**
 * Resolves a layout entry's `block` reference to a display name.
 *
 * Layout entries reference a block either as a string registry name (e.g.
 * `"hero-banner"`) or as the block class itself (the result of `import`ing
 * from a `@block`-decorated module). Both forms are valid in
 * `api.renderBlocks(...)` calls; this helper normalises both into the
 * canonical block name string.
 *
 * @param {string|Function} blockRef - A registry name or a `@block` class.
 * @returns {string} The block name, or `"(unknown)"` when the reference
 *   cannot be resolved.
 */
function resolveBlockName(blockRef) {
  if (blockRef == null) {
    return "(unknown)";
  }
  if (typeof blockRef === "string") {
    return blockRef;
  }
  return getBlockMetadata(blockRef)?.blockName ?? "(unknown)";
}

/**
 * @param {{ blocksService: any }} options
 * @returns {Promise<Array<{outletName: string, rows: Array<Object>}>>}
 */
export async function walkAllOutlets({ blocksService }) {
  const result = [];
  const outlets = blocksService.listOutlets();
  const layoutMap = _getOutletLayouts();

  for (const outletName of outlets) {
    if (!blocksService.hasLayout(outletName)) {
      continue;
    }
    const entry = layoutMap.get(outletName);
    if (!entry) {
      continue;
    }
    let layout;
    try {
      layout = await entry.validatedLayout;
    } catch {
      // Skip outlets whose layout failed validation. They show nothing in
      // the outline rather than an error row — Phase 1 is read-only and
      // surfacing layout errors in the outline isn't useful yet.
      continue;
    }
    const rows = [];
    walkEntries(layout, 0, [], rows);
    result.push({ outletName, rows });
  }
  return result;
}

function walkEntries(entries, depth, path, rows) {
  entries.forEach((entry, index) => {
    const entryPath = [...path, index];
    const blockName = resolveBlockName(entry.block);
    // Composite key matching the form minted in entry-processing.js (the
    // BLOCK_DEBUG callback receives the same value), so outline ↔ canvas
    // selection compares apples to apples.
    const blockKey = `${blockName}:${entry.__stableKey}`;
    rows.push({
      depth,
      blockName,
      blockId: entry.id,
      blockKey,
      args: entry.args ?? {},
      conditions: entry.conditions,
      hasChildren: !!(entry.children && entry.children.length),
      path: entryPath,
    });
    if (entry.children?.length) {
      walkEntries(entry.children, depth + 1, [...entryPath, "children"], rows);
    }
  });
}
