// @ts-check
/**
 * Block Entry Processing
 *
 * This module contains utilities for processing block entries and creating
 * renderable components. These functions iterate through pre-processed block
 * entries and transform them into curried Glimmer components.
 *
 * The functions use dependency injection for authorization-dependent operations
 * (`createChildBlockFn`, `isContainerBlockFn`) to maintain the authorization model
 * in the main block-outlet module.
 *
 * @module discourse/lib/blocks/-internals/entry-processing
 */
import {
  buildContainerPath,
  createGhostBlock,
  handleOptionalMissingBlock,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { isOptionalMissing } from "discourse/lib/blocks/-internals/patterns";
import { tryResolveBlock } from "discourse/lib/blocks/-internals/registry/block";
import { shallowArgsEqual } from "discourse/lib/blocks/-internals/utils";

/**
 * Gets or creates a curried component for a leaf block, using cache when possible.
 *
 * Only leaf blocks (blocks without children) are cached. Container blocks are
 * always recreated because their children's visibility may change between
 * renders, and caching would result in stale children being displayed.
 *
 * Cache hit conditions:
 * 1. The component class must be the same reference
 * 2. The args object must be shallowly equal
 *
 * @param {Map<string, {ComponentClass: typeof import("@glimmer/component").default, args: Object, result: Object}>} cache - The component cache keyed by stable block keys.
 * @param {Object} entry - The block entry with __stableKey and optional children.
 * @param {typeof import("@glimmer/component").default} resolvedBlock - The resolved block component class.
 * @param {Object} debugContext - Debug context for visual overlay and hierarchy tracking.
 * @param {string} debugContext.key - Stable unique key for this block.
 * @param {string} debugContext.displayHierarchy - Where the block is rendered (for tooltip display).
 * @param {string} debugContext.outletName - The outlet name for wrapper class generation.
 * @param {string} [debugContext.containerPath] - Container's full path (for children's __hierarchy).
 * @param {Object} [debugContext.conditions] - The block's conditions.
 * @param {Object} debugContext.outletArgs - Outlet arguments passed from the parent.
 * @param {Array<Object>} [debugContext.processedChildren] - Pre-processed children for container blocks.
 * @param {import("@ember/owner").default} owner - The application owner for service lookup.
 * @param {Function} createChildBlockFn - Function to create child block components (injected from block-outlet.gjs).
 * @returns {{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined, key: string}}
 *   The cached or newly created component data with stable key for list rendering.
 */
function getOrCreateLeafBlockComponent(
  cache,
  entry,
  resolvedBlock,
  debugContext,
  owner,
  createChildBlockFn
) {
  const { key } = debugContext;
  const cachedEntry = cache.get(key);
  const hasChildren = entry.children?.length > 0;

  // Only cache leaf blocks (no children). Container blocks are always recreated
  // to ensure their children reflect current visibility state.
  if (
    !hasChildren &&
    cachedEntry &&
    cachedEntry.ComponentClass === resolvedBlock &&
    shallowArgsEqual(cachedEntry.args, entry.args)
  ) {
    return cachedEntry.result;
  }

  // Create new curried component
  const result = createChildBlockFn(
    { ...entry, block: resolvedBlock },
    owner,
    debugContext
  );

  // Cache leaf blocks for future reuse
  if (!hasChildren) {
    cache.set(key, {
      ComponentClass: resolvedBlock,
      args: entry.args,
      result,
    });
  }

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
 * @property {boolean} __visible - Whether the block passed condition evaluation.
 * @property {number} __stableKey - Stable key assigned at registration time.
 * @property {string} [__failureReason] - Why the block is hidden (debug mode only).
 *
 * @typedef {Object} ChildBlockResult
 * @property {import("ember-curry-component").CurriedComponent} Component - Curried component ready to render.
 * @property {Object} [containerArgs] - Values for parent container's childArgs schema.
 * @property {string} key - Stable unique key for list rendering.
 *
 * @param {Object} options - Rendering options.
 * @param {Array<BlockEntry>} options.entries - Pre-processed block entries with visibility metadata.
 * @param {Map<string, {ComponentClass: typeof import("@glimmer/component").default, args: Object, result: ChildBlockResult}>} options.cache - Component cache keyed by stable block keys.
 * @param {import("@ember/owner").default} options.owner - Application owner for service lookup.
 * @param {string} options.baseHierarchy - Current hierarchy path (e.g., "homepage-blocks/section-1").
 * @param {string} options.outletName - The outlet name for CSS class generation.
 * @param {Object} options.outletArgs - Arguments passed from the outlet to blocks.
 * @param {boolean} options.showGhosts - Whether to render ghost blocks for invisible entries.
 * @param {boolean} options.isLoggingEnabled - Whether debug logging is active.
 * @param {Function} options.createChildBlockFn - Function to create child block components (injected from block-outlet.gjs).
 * @param {Function} options.isContainerBlockFn - Function to check if a block is a container (injected from block-outlet.gjs).
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
  isContainerBlockFn,
}) {
  const result = [];
  const containerCounts = new Map();

  for (const entry of entries) {
    // @ts-ignore - entry.block can be string or BlockClass
    const resolvedBlock = tryResolveBlock(entry.block);

    // Handle optional missing block (block ref ended with `?` but not registered)
    if (isOptionalMissing(resolvedBlock)) {
      const key = `optional-missing:${resolvedBlock.name}:${entry.__stableKey}`;
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

    // Skip blocks that haven't resolved yet. Block factories may be resolving
    // asynchronously (e.g., lazy-loaded plugins). The component will automatically
    // re-render when the factory resolves (via TrackedMap reactivity).
    if (!resolvedBlock) {
      continue;
    }

    const blockClass =
      /** @type {import("discourse/lib/blocks/-internals/registry/block").BlockClass} */ (
        resolvedBlock
      );
    const blockName = blockClass.blockName || "unknown";
    const isContainer = isContainerBlockFn(blockClass);

    // Use the stable key assigned at registration time. This key survives
    // shallow cloning and ensures DOM identity is maintained when blocks
    // are hidden/shown by conditions.
    const key = `${blockName}:${entry.__stableKey}`;

    // For containers, build their full path for children's hierarchy
    const containerPath = isContainer
      ? buildContainerPath(blockName, baseHierarchy, containerCounts)
      : undefined;

    // For containers with children, recursively process children FIRST
    // This creates the child components at the root level, so containers
    // receive pre-processed children via @children arg instead of raw entries.
    let processedChildren;
    if (isContainer && entry.children?.length) {
      processedChildren = processBlockEntries({
        entries: entry.children,
        cache, // Same root cache for all levels
        owner,
        baseHierarchy: containerPath,
        outletName,
        outletArgs,
        showGhosts,
        isLoggingEnabled,
        createChildBlockFn,
        isContainerBlockFn,
      });
    }

    // Render visible blocks
    if (entry.__visible) {
      result.push(
        getOrCreateLeafBlockComponent(
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
