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
 *     for re-locating the entry from the layout root.
 *
 * The walker filters to outlets whose `<OutletBoundary>` is actually
 * mounted in the DOM, so outlets registered site-wide but not mounted
 * on the current page don't show up as dead rows. The editor mounts
 * the boundary for active outlets via the OUTLET_INFO_COMPONENT
 * callback — see `api-initializers/wireframe.js`. Falls back to the
 * unfiltered list during tests / SSR where `document` isn't a
 * meaningful DOM source.
 */
import { _getOutletLayouts } from "discourse/blocks/block-outlet";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

/**
 * Resolves a layout entry's `block` reference into a display name plus
 * an `unknown` flag.
 *
 * Layout entries reference a block either as a string registry name (e.g.
 * `"hero-banner"`) or as the block class itself (the result of `import`ing
 * from a `@block`-decorated module). Both forms are valid in
 * `api.renderBlocks(...)` calls; this helper normalises both into the
 * canonical block name string AND verifies the resulting name is
 * registered with the blocks service. A string ref that doesn't resolve
 * (typo, removed block, renamed registration) keeps its raw name so
 * the author can still find the offending entry in the outline, but is
 * flagged `unknown: true` so callers can paint an error indicator.
 *
 * @param {string|Function} blockRef - A registry name or a `@block` class.
 * @param {any} blocksService - The Discourse `blocks` service; used to
 *   verify that string refs resolve to registered blocks.
 * @returns {{ name: string, unknown: boolean }}
 */
function resolveBlockName(blockRef, blocksService) {
  if (blockRef == null) {
    return { name: "(unknown)", unknown: true };
  }
  if (typeof blockRef === "string") {
    const unknown = !blocksService?.hasBlock?.(blockRef);
    return { name: blockRef, unknown };
  }
  const resolved = getBlockMetadata(blockRef)?.blockName;
  if (!resolved) {
    return { name: "(unknown)", unknown: true };
  }
  // Class refs come from `import` of a `@block`-decorated module — the
  // decorator registers them as a side effect, so by the time we see
  // the class the name is registered. Skipping the `hasBlock` check
  // here keeps the walker pure-function on the class branch.
  return { name: resolved, unknown: false };
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
export function mountedOutletNames() {
  if (typeof document === "undefined") {
    return null;
  }
  const nodes = document.querySelectorAll(
    ".wireframe-outlet-boundary[data-outlet-name]"
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
 * @param {object} options
 * @param {any} options.blocksService
 * @param {Set<string>} [options.alwaysInclude] - Outlet names the
 *   caller wants kept regardless of the DOM scan. The editor passes
 *   the outlets it has materialized session-drafts for, so a publish-
 *   driven re-render (which briefly unmounts the boundary during
 *   `DAsyncContent`'s `:loading` block) doesn't drop the row from
 *   the outline mid-edit.
 * @returns {Promise<Array<{outletName: string, rows: Array<Object>}>>}
 */
export async function walkAllOutlets({ blocksService, alwaysInclude }) {
  const result = [];
  const outlets = blocksService.listOutlets();
  const layoutMap = _getOutletLayouts();
  const mounted = mountedOutletNames();

  // Sync prefix: touch every entry's soft-failure stamps before the
  // first `await`, so the reads attach to the caller's tracking frame
  // (typically a `@cached` getter wrapping the returned Promise in
  // `TrackedAsyncData`). The entry shells are `trackedObject` proxies,
  // so each touched key opens a per-key tag dep — when the validator
  // stamps an entry or `clearValidatorStamps` clears one, the tag
  // fires and the caller recomputes. Without this, the stamp reads in
  // `walkEntries` below happen post-await and never subscribe.
  for (const [, record] of layoutMap) {
    if (record?.layout) {
      touchStamps(record.layout);
    }
  }

  for (const outletName of outlets) {
    if (!blocksService.hasLayout(outletName)) {
      continue;
    }
    // Filter to outlets actually rendered on this page when we can tell
    // (mounted is null only in environments where the DOM query can't
    // resolve — tests, SSR — at which point we walk everything).
    // `alwaysInclude` lets the editor pin outlets it knows it has
    // touched this session — the DOM boundary briefly disappears
    // during a publish cycle and we don't want the outline to flicker
    // the outlet out and back.
    const forceInclude = alwaysInclude?.has(outletName);
    if (mounted && !mounted.has(outletName) && !forceInclude) {
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
      // Skip outlets whose layout failed validation. They show nothing
      // in the outline rather than an error row — layout-level errors
      // surface elsewhere (the validator's own error reporting).
      continue;
    }
    // Each editable outlet is normalised to a single root `layout` block
    // (its children are the outlet's blocks). Present that root AS the outlet:
    // expose its key + mode on the group (so the header selects it and shows
    // the mode) and walk its children at depth 0 — no redundant "layout" row.
    // Layouts not in this shape (e.g. an un-drafted flat layout) walk as-is.
    const rows = [];
    const root = layout.length === 1 ? layout[0] : null;
    const rootIsLayout =
      root && resolveBlockName(root.block, blocksService).name === "layout";
    if (rootIsLayout) {
      walkEntries(root.children ?? [], 0, [0, "children"], rows, blocksService);
      result.push({
        outletName,
        rows,
        rootKey: `layout:${root.__stableKey}`,
        mode: normalizeLayoutMode(root.args?.mode),
      });
    } else {
      walkEntries(layout, 0, [], rows, blocksService);
      result.push({ outletName, rows, rootKey: null, mode: null });
    }
  }
  return result;
}

/**
 * Normalises a layout `mode` arg for display, mapping the legacy
 * `"free-grid"` value to `"grid"` and defaulting to `"stack"`.
 *
 * @param {string|undefined} mode
 * @returns {string}
 */
function normalizeLayoutMode(mode) {
  if (mode === "free-grid") {
    return "grid";
  }
  return mode ?? "stack";
}

/**
 * Recursively reads each entry's `__failureType` / `__failureReason` /
 * `__failureDetails` fields. Side-effect-only: the reads exist purely
 * to subscribe the surrounding tracking frame to the trackedObject-
 * wrapped entries' per-key tags. Validator stamp writes / clears then
 * propagate to the caller automatically.
 *
 * @param {Array<Object>} entries
 */
function touchStamps(entries) {
  for (const entry of entries) {
    void entry.__failureType;
    void entry.__failureReason;
    void entry.__failureDetails;
    if (entry.children?.length) {
      touchStamps(entry.children);
    }
  }
}

function walkEntries(entries, depth, path, rows, blocksService) {
  entries.forEach((entry, index) => {
    const entryPath = [...path, index];

    const { name: blockName, unknown } = resolveBlockName(
      entry.block,
      blocksService
    );
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
      hasConditions: entry.conditions != null,
      // `isUnknown` flags entries whose block reference can't be
      // resolved to a registered block — typo in the block name,
      // renamed / removed registration, or a `null`/missing block
      // reference. The outline shows these with a warning icon so
      // authors can find and fix them.
      isUnknown: unknown,
      // `validationFailure` surfaces soft-failures stamped on the entry
      // by `validateLayout` in permissive mode (`__failureType =
      // "structural-invalid"`, `__failureReason` set to the original
      // BlockError message — e.g. "Container must have children" for
      // an empty `wf:layout`). The outline reads these to paint the
      // row as an error so authors can find the offending entry.
      // `__failureDetails` is the structured payload (array of
      // `{ code, field?, value?, expected? }`) that drives per-field
      // errors in the inspector.
      validationFailure: entry.__failureType ?? null,
      validationReason: entry.__failureReason ?? null,
      validationDetails: entry.__failureDetails ?? null,
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
