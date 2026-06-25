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
import { synthesizePartEntries } from "discourse/lib/blocks/-internals/composite";
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
  const layoutMap = blocksService.resolvedLayouts();
  // Outlets actually on this page, from the blocks service's mounted-outlet
  // registry (populated by each `<BlockOutlet>`'s lifecycle at page render). A
  // point-in-time snapshot; the walk re-runs off the tracked layout layers it
  // reads below (e.g. when an outlet's draft is materialised).
  const mounted = blocksService.mountedOutletNames();

  // Block-name → metadata index, built once. Lets `walkEntries` recognise a
  // composite (a block declaring a `parts` composition) and emit its parts as
  // nested rows without re-walking the registry per entry.
  const metadataByName = new Map(
    blocksService.listBlocksWithMetadata().map((b) => [b.name, b.metadata])
  );

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
    // Keep an outlet that has a layout, OR is mounted on this page (so an
    // empty, layout-less outlet still gets a row once the editor materialises
    // its draft), OR is pinned via `alwaysInclude` (the editor keeps outlets it
    // touched this session from flickering out during a publish re-render).
    // Off-page outlets — registered but neither mounted nor laid out here — are
    // dropped so they don't show as dead rows.
    const forceInclude = alwaysInclude?.has(outletName);
    if (
      !blocksService.hasLayout(outletName) &&
      !mounted.has(outletName) &&
      !forceInclude
    ) {
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
      walkEntries(
        root.children ?? [],
        0,
        [0, "children"],
        rows,
        blocksService,
        metadataByName,
        "layout"
      );
      result.push({
        outletName,
        rows,
        rootKey: `layout:${root.__stableKey}`,
        mode: normalizeLayoutMode(root.args?.mode),
      });
    } else {
      walkEntries(layout, 0, [], rows, blocksService, metadataByName);
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
export function normalizeLayoutMode(mode) {
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

// Containers whose children are numbered by ordinal (e.g. a carousel's slides,
// a tabs block's panels), mapping the parent block name to the i18n key that
// renders the per-child label, resolved with `number = index + 1`. Shared by the
// outline and the block toolbar so both name a child "Slide 2" / "Tab 2".
export const CHILD_NUMBER_KEY_BY_PARENT = Object.freeze({
  carousel: "blocks.builtin.carousel.slide_number",
  tabs: "blocks.builtin.tabs.tab_number",
});

// Containers whose children carry an author-set label preferred as a tooltip
// over the ordinal — mapping the parent block name to the `containerArgs`
// namespace holding a `label` rich-text field (e.g. a tab's own label). Empty
// labels fall back to the ordinal above.
export const CHILD_LABEL_NAMESPACE_BY_PARENT = Object.freeze({
  tabs: "tab",
});

// Containers that frame their children with a noun, mapping the container block
// name to the i18n key for that noun (singular). Lets the empty-state call to
// action read "Add a tab to get started" / "Add a slide to get started" instead
// of the generic "Drag a block here".
export const CHILD_NOUN_KEY_BY_PARENT = Object.freeze({
  carousel: "blocks.builtin.carousel.slide_noun",
  tabs: "blocks.builtin.tabs.tab_noun",
});

/**
 * Flattens an inline rich-text value to its plain text for compact display in
 * the outline. The value is either a plain string or doc JSON with a `content`
 * array of text runs (`{ type: "text", text }`); anything else yields "".
 *
 * @param {*} value - The rich-inline arg value.
 * @returns {string}
 */
export function richInlineToPlainText(value) {
  if (typeof value === "string") {
    return value;
  }
  if (value && Array.isArray(value.content)) {
    return value.content
      .filter((run) => run?.type === "text" && typeof run.text === "string")
      .map((run) => run.text)
      .join("");
  }
  return "";
}

function walkEntries(
  entries,
  depth,
  path,
  rows,
  blocksService,
  metadataByName,
  parentBlockName = null
) {
  // When the parent is a noun-framed container, each child row gets a 1-based
  // ordinal label ("Slide 2") so the slides are identifiable in the tree.
  const childNumberKey = parentBlockName
    ? (CHILD_NUMBER_KEY_BY_PARENT[parentBlockName] ?? null)
    : null;
  // When the parent labels its children, the outline prefers that label over the
  // ordinal (e.g. a tab named "Pricing" rather than "Tab 2").
  const childLabelNamespace = parentBlockName
    ? (CHILD_LABEL_NAMESPACE_BY_PARENT[parentBlockName] ?? null)
    : null;
  entries.forEach((entry, index) => {
    const entryPath = [...path, index];

    const { name: blockName, unknown } = resolveBlockName(
      entry.block,
      blocksService
    );
    // Composite key matching the form minted in entry-processing.js (the
    // BLOCK_DEBUG callback receives the same value), so outline ↔ canvas
    // selection compares apples to apples. For a synthesized part this is the
    // part key (`${blockName}:${compositeKey}::part::${id}`), which also
    // matches what the canvas chrome carries.
    const blockKey = `${blockName}:${entry.__stableKey}`;
    // A composite (declares `parts`) that supplies no `children` of its own
    // renders its composition; surface those parts as nested rows. An entry
    // with its own children is a plain container and walks those instead.
    const metadata = metadataByName.get(blockName) ?? null;
    const hasParts = !!(metadata?.parts && entry.children == null);
    // Synthesize the composite's parts once (reused for both the child-count
    // and the recursive walk below) so a part-backed container reports the
    // same count it actually renders as rows.
    const partEntries = hasParts
      ? synthesizePartEntries(entry, metadata)
      : null;
    // An author-set child label (e.g. a tab's own label), used as the outline
    // row's tooltip; null when the parent doesn't label its children or the
    // label is empty.
    const childLabel = childLabelNamespace
      ? richInlineToPlainText(
          entry.containerArgs?.[childLabelNamespace]?.label
        ).trim() || null
      : null;
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
      // `isPart` marks a synthesized composite part (no persisted entry).
      // The outline keeps these selectable but opts them out of drag/drop —
      // a code-defined part isn't reorderable.
      isPart: !!entry.__fromComposite,
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
      // Per-child ordinal label for a noun-framed parent (e.g. "Slide 2");
      // null otherwise. `slideNumberKey` is the i18n key the outline resolves
      // and shows AS the row name in place of the block name.
      slideOrdinal: childNumberKey ? index + 1 : null,
      slideNumberKey: childNumberKey,
      // The child's own author-set label (a tab's "Pricing"), used as the
      // outline row's hover tooltip; null when unset. The block name + ordinal
      // are already in the visible row text, so the tooltip only adds the label.
      childLabel,
      hasChildren: !!(entry.children && entry.children.length) || hasParts,
      // Number of nested rows this container contributes (own children, or
      // synthesized composite parts). Drives the outline's "× N" count badge
      // and the auto-collapse-past-threshold compaction.
      childCount: entry.children?.length ?? partEntries?.length ?? 0,
      path: entryPath,
    });
    if (entry.children?.length) {
      walkEntries(
        entry.children,
        depth + 1,
        [...entryPath, "children"],
        rows,
        blocksService,
        metadataByName,
        blockName
      );
    } else if (partEntries) {
      walkEntries(
        partEntries,
        depth + 1,
        [...entryPath, "parts"],
        rows,
        blocksService,
        metadataByName,
        blockName
      );
    }
  });
}
