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
 * Phase 7p filter: outlets registered site-wide but not mounted on the
 * current page would otherwise show up as dead rows. The walker filters
 * to outlets whose `<OutletBoundary>` is actually in the DOM (the editor
 * always mounts the boundary for active outlets via the
 * OUTLET_INFO_COMPONENT callback — see `api-initializers/visual-editor.js`).
 * Falls back to the unfiltered list during tests / SSR where `document`
 * isn't a meaningful DOM source.
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
 * Returns the set of outlet names whose `<OutletBoundary>` is currently
 * mounted in the DOM. Filters the walker to those outlets so layouts
 * registered for off-page outlets don't show as dead rows.
 *
 * Returns `null` when `document` isn't usable (Node-side / SSR / some
 * test environments) so callers can fall back to the full list.
 *
 * @returns {Set<string>|null}
 */
function mountedOutletNames() {
  if (typeof document === "undefined") {
    return null;
  }
  const nodes = document.querySelectorAll(
    ".visual-editor-outlet-boundary[data-outlet-name]"
  );
  if (nodes.length === 0) {
    return null;
  }
  const names = new Set();
  for (const node of nodes) {
    const name = node.getAttribute("data-outlet-name");
    if (name) {
      names.add(name);
    }
  }
  return names;
}

/**
 * @param {{ blocksService: any }} options
 * @returns {Promise<Array<{outletName: string, rows: Array<Object>}>>}
 */
export async function walkAllOutlets({ blocksService }) {
  const result = [];
  const outlets = blocksService.listOutlets();
  const layoutMap = _getOutletLayouts();
  const mounted = mountedOutletNames();

  for (const outletName of outlets) {
    if (!blocksService.hasLayout(outletName)) {
      continue;
    }
    // Filter to outlets actually rendered on this page when we can tell
    // (mounted is null only in environments where the DOM query can't
    // resolve — tests, SSR — at which point we walk everything).
    if (mounted && !mounted.has(outletName)) {
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
    walkEntries(layout, 0, [], rows, blocksService);
    result.push({ outletName, rows });
  }
  return result;
}

function walkEntries(entries, depth, path, rows, blocksService) {
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
      walkEntries(
        entry.children,
        depth + 1,
        [...entryPath, "children"],
        rows,
        blocksService
      );
    }
  });
}
