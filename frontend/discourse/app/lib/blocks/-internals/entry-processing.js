// @ts-check
/**
 * Block Entry Processing
 *
 * This module contains utilities for processing block entries and creating
 * renderable components. These functions iterate through pre-processed block
 * entries and transform them into curried Glimmer components.
 *
 * The functions use dependency injection for the authorization-dependent operation
 * `createChildBlockFn` to maintain the authorization model in the main block-outlet
 * module.
 *
 * @module discourse/lib/blocks/-internals/entry-processing
 */
import { trackedObject } from "@ember/reactive/collections";
import { synthesizePartEntries } from "discourse/lib/blocks/-internals/composite";
import {
  buildContainerPath,
  createGhostBlock,
  debugHooks,
  handleOptionalMissingBlock,
  handleUnknownBlock,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { isOptionalMissing } from "discourse/lib/blocks/-internals/patterns";
import { tryResolveBlock } from "discourse/lib/blocks/-internals/registry/block";
import { shallowArgsEqual } from "discourse/lib/blocks/-internals/utils";

/**
 * Gets or creates a curried component for a block, using the cache when possible.
 *
 * Both leaf and container blocks are cached, keyed by their stable block key.
 * Caching the curried component preserves its identity across renders, so the
 * `{{#each ... key="key"}}` that renders it keeps the same component instance
 * (and its DOM subtree) instead of tearing it down and remounting. This matters
 * most for containers: re-currying a container produces a new component value,
 * which forces a full remount of its subtree — including any children that
 * load data — on every structural change anywhere in the outlet.
 *
 * Containers do not bake their children into the curry. Instead the cache holds
 * a tracked `holder` whose `current` value is the freshly processed children;
 * the curry reads `holder.current` reactively, so a cached container reflects
 * new/removed children without being recreated.
 *
 * Cache hit conditions:
 * 1. The component class is the same reference.
 * 2. The own args are shallowly equal.
 * 3. The `containerArgs` reference is identical — it's read by the parent
 *    container as a one-shot snapshot, so a replaced reference (e.g. a grid
 *    placement edit) must produce a fresh result.
 * 4. The hierarchy (`displayHierarchy`/`containerPath`) is unchanged — both are
 *    baked into the curry and the debug payload. A moved entry keeps its stable
 *    key (hence its cache slot), so the hierarchy guard forces a fresh curry,
 *    and a fresh debug payload, when an entry changes parent.
 * 5. The debug-overlay toggle state (`debugWrapKey`) is unchanged. The debug
 *    callback wraps the block with an overlay component only while a toggle is
 *    on, so flipping one must re-curry (re-run the callback) rather than reuse
 *    the previously wrapped/unwrapped result. Constant in production.
 *
 * Children are deliberately excluded from the match: a container reflects child
 * changes through its tracked holder, not by re-currying.
 *
 * @param {Map<string, {ComponentClass: typeof import("@glimmer/component").default, args: Object, containerArgs?: Object, displayHierarchy?: string, containerPath?: string, debugWrapKey?: string, holder?: {current: Array<Object>}, result: Object}>} cache - The component cache keyed by stable block keys.
 * @param {Object} entry - The block entry with __stableKey and optional children.
 * @param {typeof import("@glimmer/component").default} resolvedBlock - The resolved block component class.
 * @param {Object} debugContext - Debug context for visual overlay and hierarchy tracking.
 * @param {string} debugContext.key - Stable unique key for this block.
 * @param {string} debugContext.displayHierarchy - Where the block is rendered (for tooltip display).
 * @param {string} debugContext.outletName - The outlet name for wrapper class generation.
 * @param {string} [debugContext.containerPath] - Container's full path (for children's __hierarchy).
 * @param {boolean} [debugContext.isContainer] - Whether the block is a container (gets a children holder).
 * @param {Object} [debugContext.conditions] - The block's conditions.
 * @param {Object} debugContext.outletArgs - Outlet arguments passed from the parent.
 * @param {Array<Object>} [debugContext.processedChildren] - Pre-processed children for container blocks.
 * @param {import("@ember/owner").default} owner - The application owner for service lookup.
 * @param {Function} createChildBlockFn - Function to create child block components (injected from block-outlet.gjs).
 * @returns {ChildBlockResult} The cached or newly created component data with stable key for list rendering.
 */
function getOrCreateBlockComponent(
  cache,
  entry,
  resolvedBlock,
  debugContext,
  owner,
  createChildBlockFn
) {
  const { key, displayHierarchy, containerPath } = debugContext;
  const cachedEntry = cache.get(key);

  // The debug callback (run inside `createChildBlockFn`) wraps a block with a
  // visual-overlay / ghost component whose presence depends on the current
  // debug toggles. That wrapping isn't reflected in the args or hierarchy, so
  // fold the toggle state into the cache key: flipping a debug overlay must
  // re-curry the block (re-running the debug callback) rather than reuse the
  // previously wrapped/unwrapped result. In production both flags are a stable
  // `false`, so ordinary caching and container-instance survival are unchanged.
  const debugWrapKey = `${debugHooks.isVisualOverlayEnabled}:${debugHooks.isGhostBlocksEnabled}`;

  if (
    cachedEntry &&
    cachedEntry.ComponentClass === resolvedBlock &&
    shallowArgsEqual(cachedEntry.args, entry.args) &&
    cachedEntry.containerArgs === entry.containerArgs &&
    cachedEntry.displayHierarchy === displayHierarchy &&
    cachedEntry.containerPath === containerPath &&
    cachedEntry.debugWrapKey === debugWrapKey
  ) {
    // Refresh the children a cached container's curry reads from. Do NOT rebuild
    // the wrapper or re-run the debug callback here — instance survival depends
    // on `result.Component` keeping its identity across renders.
    if (cachedEntry.holder) {
      cachedEntry.holder.current = debugContext.processedChildren;
    }
    return cachedEntry.result;
  }

  // Every container gets a tracked holder seeded with its current children
  // (which may be undefined for a container rendered empty), threaded into the
  // curry so later renders refresh it in place rather than re-currying. Seeding
  // the holder unconditionally for containers is what lets a container that
  // starts empty pick up its first child on a later edit — without it, an empty
  // container would bake a static `undefined` children value and never update.
  const holder = debugContext.isContainer
    ? trackedObject({ current: debugContext.processedChildren })
    : undefined;

  const result = createChildBlockFn(
    { ...entry, block: resolvedBlock },
    owner,
    holder ? { ...debugContext, childrenHolder: holder } : debugContext
  );

  cache.set(key, {
    ComponentClass: resolvedBlock,
    args: entry.args,
    containerArgs: entry.containerArgs,
    displayHierarchy,
    containerPath,
    debugWrapKey,
    holder,
    result,
  });

  return result;
}

/**
 * Processes block entries and creates renderable child components.
 *
 * This function iterates through a list of pre-processed block entries and
 * transforms them into renderable components, handling ghost blocks for
 * debug mode and optional missing blocks.
 *
 * @typedef {Object} BlockEntry
 * @property {string|typeof import("@glimmer/component").default} block - Block reference (string name or class).
 * @property {Object} [args] - Arguments to pass to the block.
 * @property {Object} [containerArgs] - Values for parent container's childArgs schema.
 * @property {Array<BlockEntry>} [children] - Nested block entries for containers.
 * @property {Object|Array<Object>} [conditions] - Conditions that must pass for block to render.
 * @property {string} [classNames] - Additional CSS classes for the block wrapper.
 * @property {string} [id] - Unique identifier for BEM styling and targeting.
 * @property {boolean} __visible - Whether the block passed condition evaluation.
 * @property {number} __stableKey - Stable key assigned at registration time.
 * @property {string} [__failureType] - The failure type constant (debug mode only).
 * @property {string} [__failureReason] - Custom failure reason message (debug mode only).
 *
 * @typedef {Object} ChildBlockResult
 * @property {import("ember-curry-component").CurriedComponent} Component - Curried component ready to render.
 * @property {Object} [containerArgs] - Values for parent container's childArgs schema.
 * @property {string} key - Stable unique key for list rendering.
 * @property {string} [blockName] - The child block's registered name, so a
 *   parent container can identify a child by kind (e.g. filter out
 *   `layout-merged-cell` on the live path) without inspecting the curried
 *   component.
 * @property {boolean} [isGhost] - True if this is a ghost block (debug mode only).
 * @property {(reason: string) => ChildBlockResult|null} [asGhost] - Returns a ghost version of this child with the given reason.
 *   For regular children, creates a new ghost component (or null if debug mode is disabled).
 *   For ghost children, returns self (no-op).
 *
 * @param {Object} options - Rendering options.
 * @param {Array<BlockEntry>} options.entries - Pre-processed block entries with visibility metadata.
 * @param {Map<string, {ComponentClass: typeof import("@glimmer/component").default, args: Object, containerArgs?: Object, displayHierarchy?: string, containerPath?: string, holder?: {current: Array<Object>}, result: ChildBlockResult}>} options.cache - Component cache keyed by stable block keys.
 * @param {import("@ember/owner").default} options.owner - Application owner for service lookup.
 * @param {string} options.baseHierarchy - Current hierarchy path (e.g., "homepage-blocks/section-1").
 * @param {string} options.outletName - The outlet name for CSS class generation.
 * @param {Object} options.outletArgs - Arguments passed from the outlet to blocks.
 * @param {boolean} options.showGhosts - Whether to render ghost blocks for invisible entries.
 * @param {boolean} options.isLoggingEnabled - Whether debug logging is active.
 * @param {Function} options.createChildBlockFn - Function to create child block components (injected from block-outlet.gjs).
 * @returns {Array<ChildBlockResult>} Array of renderable child objects with Component and containerArgs.
 */
export function processBlockEntries({
  entries,
  cache,
  owner,
  baseHierarchy,
  outletName,
  outletArgs,
  showGhosts,
  isLoggingEnabled,
  createChildBlockFn,
}) {
  const result = [];
  const containerCounts = new Map();

  for (const entry of entries) {
    // @ts-ignore - entry.block can be string or BlockClass
    const resolvedBlock = tryResolveBlock(entry.block);

    // Handle optional missing block (block ref ended with `?` but not registered)
    if (isOptionalMissing(resolvedBlock)) {
      // Use the canonical `${name}:${__stableKey}` key (the same shape
      // resolved blocks get below). This key is forwarded into the
      // BLOCK_DEBUG payload, where consumers use it to correlate the ghost
      // back to its layout entry — a categorising prefix here would make
      // those lookups (selection, removal) miss.
      const key = `${resolvedBlock.name}:${entry.__stableKey}`;
      const ghostData = handleOptionalMissingBlock({
        blockName: resolvedBlock.name,
        entry,
        hierarchy: baseHierarchy,
        isLoggingEnabled,
        showGhosts,
        key,
      });
      if (ghostData) {
        result.push(ghostData);
      }
      continue;
    }

    // Block didn't resolve. Two flavours of this:
    //   1. Async factory still resolving — common at boot, the trackedMap
    //      will re-evaluate this getter once the factory lands.
    //   2. Truly unknown block (typo in a saved layout, plugin not
    //      installed, etc.). Strict rendering silently skips these. When
    //      `showGhosts` is enabled, the author sees a labelled placeholder
    //      and can swap or remove the entry.
    if (!resolvedBlock) {
      if (showGhosts) {
        const blockName =
          typeof entry.block === "string" ? entry.block : "(unknown)";
        const stableKey = entry.__stableKey ?? "no-key";
        // When the unknown entry has children it was authored as a
        // container; give it a path so its ghost children get distinct
        // hierarchies/keys from any sibling unknown container. This also
        // consumes a slot in the same counting space as resolved
        // containers, keeping sibling indices stable.
        const containerPath = entry.children?.length
          ? buildContainerPath(
              blockName,
              entry.id,
              baseHierarchy,
              containerCounts
            )
          : undefined;
        const ghostData = handleUnknownBlock({
          blockName,
          entry,
          hierarchy: baseHierarchy,
          showGhosts,
          // Canonical `${name}:${__stableKey}` key — see the matching note
          // in the optional-missing branch above. Consumers correlate the
          // ghost back to its layout entry by this key, so it must not carry
          // a categorising prefix.
          key: `${blockName}:${stableKey}`,
          owner,
          outletArgs,
          isLoggingEnabled,
          containerPath,
          resolveBlockFn: tryResolveBlock,
        });
        if (ghostData) {
          result.push(ghostData);
        }
      }
      continue;
    }

    const blockClass =
      /** @type {import("discourse/lib/blocks/-internals/registry/block").BlockClass} */ (
        resolvedBlock
      );
    const blockMeta = getBlockMetadata(blockClass);
    const blockName = blockMeta?.blockName || "unknown";
    const isContainer = blockMeta?.isContainer ?? false;

    // Use the stable key assigned at registration time. This key survives
    // shallow cloning and ensures DOM identity is maintained when blocks
    // are hidden/shown by conditions.
    const key = `${blockName}:${entry.__stableKey}`;

    // For containers, build their full path for children's hierarchy.
    // The id is included in the path for easier identification in debug tools.
    const containerPath = isContainer
      ? buildContainerPath(blockName, entry.id, baseHierarchy, containerCounts)
      : undefined;

    // For containers with children, recursively process children FIRST
    // This creates the child components at the root level, so containers
    // receive pre-processed children via @children arg instead of raw entries.
    //
    // A block that declares a `parts` composition and supplies no children of
    // its own renders those parts: they are synthesized into render-only child
    // entries here (never persisted). A part that is itself a composition
    // re-synthesizes on the next recursion level, so nesting needs no special
    // casing. An entry that supplies its own children bypasses the composition
    // and renders as a plain container.
    let childEntries;
    if (isContainer && entry.children?.length) {
      childEntries = entry.children;
    } else if (isContainer && blockMeta?.parts && entry.children == null) {
      // Composed: a `parts` block with no `children` of its own renders its
      // composition. An entry that supplies its own `children` array — even an
      // empty one — bypasses the composition and renders as a plain container.
      childEntries = synthesizePartEntries(entry, blockMeta);
    }

    let processedChildren;
    if (childEntries?.length) {
      processedChildren = processBlockEntries({
        entries: childEntries,
        cache, // Same root cache for all levels
        owner,
        baseHierarchy: containerPath,
        outletName,
        outletArgs,
        showGhosts,
        isLoggingEnabled,
        createChildBlockFn,
      });
    }

    // Render visible blocks
    if (entry.__visible) {
      result.push(
        getOrCreateBlockComponent(
          cache,
          entry,
          blockClass,
          {
            displayHierarchy: baseHierarchy,
            outletName,
            containerPath,
            conditions: entry.conditions,
            outletArgs,
            key,
            isContainer,
            processedChildren, // Pass pre-processed children for containers
          },
          owner,
          createChildBlockFn
        )
      );
    } else if (showGhosts) {
      // Show ghost for invisible blocks in debug mode
      const ghostData = createGhostBlock({
        blockName,
        entry,
        hierarchy: baseHierarchy,
        containerPath,
        isContainer,
        owner,
        outletArgs,
        isLoggingEnabled,
        resolveBlockFn: tryResolveBlock,
        key,
      });
      if (ghostData) {
        result.push(ghostData);
      }
    }
  }

  return result;
}
