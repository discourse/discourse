/**
 * Block Entry Processing
 *
 * This module contains utilities for processing block entries and creating
 * renderable components. These functions iterate through pre-processed block
 * entries and transform them into curried Glimmer components.
 *
 * The functions use dependency injection for the authorization-dependent
 * operation `createChildBlockFn` to keep the authorization model in the main
 * block-outlet module.
 */
import type Owner from "@ember/owner";
import {
  buildContainerPath,
  createGhostBlock,
  handleOptionalMissingBlock,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { isOptionalMissing } from "discourse/lib/blocks/-internals/patterns";
import { tryResolveBlock } from "discourse/lib/blocks/-internals/registry/block";
import type {
  BlockClass,
  BlockEntry,
  ChildBlockResult,
} from "discourse/lib/blocks/-internals/types";
import { shallowArgsEqual } from "discourse/lib/blocks/-internals/utils";

/** Rendering context threaded through block processing for a single entry. */
interface DebugContext {
  /** Stable unique key for this block. */
  key: string;

  /** Where the block is rendered (used for tooltip display). */
  displayHierarchy: string;

  /** The outlet name, used for wrapper class generation. */
  outletName: string;

  /** The container's full path, used for children's hierarchy. */
  containerPath?: string;

  /** The block's conditions. */
  conditions?: BlockEntry["conditions"];

  /** Outlet arguments passed from the parent. */
  outletArgs: Record<string, unknown>;

  /** Pre-processed children for container blocks. */
  processedChildren?: ChildBlockResult[];
}

/**
 * Creates a renderable child block. Injected from `block-outlet.gts` so the
 * authorization-token logic stays in that module.
 */
export type CreateChildBlockFn = (
  entry: BlockEntry,
  owner: Owner,
  debugContext: DebugContext
) => ChildBlockResult;

/** A cached leaf-block entry, keyed by the block's stable key. */
interface LeafCacheEntry {
  ComponentClass: BlockClass;
  args?: Record<string, unknown>;
  result: ChildBlockResult;
}

export type LeafCache = Map<string, LeafCacheEntry>;

/**
 * Gets or creates a curried component for a leaf block, using the cache when
 * possible.
 *
 * Only leaf blocks (blocks without children) are cached. Container blocks are
 * always recreated because their children's visibility may change between
 * renders, and caching would show stale children.
 *
 * Cache hit conditions: the component class is the same reference, and the args
 * object is shallowly equal.
 *
 * @param cache - The component cache keyed by stable block keys.
 * @param entry - The block entry with `__stableKey` and optional children.
 * @param resolvedBlock - The resolved block component class.
 * @param debugContext - Debug context for the visual overlay and hierarchy tracking.
 * @param owner - The application owner for service lookup.
 * @param createChildBlockFn - Creates child block components (injected from block-outlet).
 * @returns The cached or newly created component data.
 */
function getOrCreateLeafBlockComponent(
  cache: LeafCache,
  entry: BlockEntry,
  resolvedBlock: BlockClass,
  debugContext: DebugContext,
  owner: Owner,
  createChildBlockFn: CreateChildBlockFn
): ChildBlockResult {
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

  // Create new curried component.
  const result = createChildBlockFn(
    { ...entry, block: resolvedBlock },
    owner,
    debugContext
  );

  // Cache leaf blocks for future reuse.
  if (!hasChildren) {
    cache.set(key, {
      ComponentClass: resolvedBlock,
      args: entry.args,
      result,
    });
  }

  return result;
}

/** Options for {@link processBlockEntries}. */
interface ProcessBlockEntriesOptions {
  /** Pre-processed block entries with visibility metadata. */
  entries: BlockEntry[];

  /** Component cache keyed by stable block keys. */
  cache: LeafCache;

  /** Application owner for service lookup. */
  owner: Owner;

  /** Current hierarchy path (e.g. "homepage-blocks/section-1"). */
  baseHierarchy: string;

  /** The outlet name, used for CSS class generation. */
  outletName: string;

  /** Arguments passed from the outlet to blocks. */
  outletArgs: Record<string, unknown>;

  /** Whether to render ghost blocks for invisible entries. */
  showGhosts: boolean;

  /** Whether debug logging is active. */
  isLoggingEnabled: boolean;

  /** Creates child block components (injected from block-outlet). */
  createChildBlockFn: CreateChildBlockFn;
}

/**
 * Processes block entries and creates renderable child components, handling
 * ghost blocks for debug mode and optional missing blocks.
 *
 * @param options - Rendering options.
 * @returns Renderable child objects with their `Component` and `containerArgs`.
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
}: ProcessBlockEntriesOptions): ChildBlockResult[] {
  const result: ChildBlockResult[] = [];
  const containerCounts = new Map<string, number>();

  for (const entry of entries) {
    const resolvedBlock = tryResolveBlock(entry.block);

    // Handle optional missing block (block ref ended with `?` but not registered).
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
    // asynchronously (e.g. lazy-loaded plugins); the component re-renders
    // automatically when the factory resolves (via TrackedMap reactivity).
    if (!resolvedBlock) {
      continue;
    }

    const blockClass = resolvedBlock;
    const blockMeta = getBlockMetadata(blockClass);
    const blockName = blockMeta?.blockName || "unknown";
    const isContainer = blockMeta?.isContainer ?? false;

    // Use the stable key assigned at registration time. This key survives shallow
    // cloning and keeps DOM identity when blocks are hidden/shown by conditions.
    const key = `${blockName}:${entry.__stableKey}`;

    // For containers, build their full path for children's hierarchy. The id is
    // included in the path for easier identification in debug tools.
    const containerPath = isContainer
      ? buildContainerPath(blockName, entry.id, baseHierarchy, containerCounts)
      : undefined;

    // For containers with children, recursively process children FIRST. This
    // creates the child components at the root level, so containers receive
    // pre-processed children via the `@children` arg instead of raw entries.
    let processedChildren: ChildBlockResult[] | undefined;
    if (isContainer && entry.children?.length) {
      processedChildren = processBlockEntries({
        entries: entry.children,
        cache, // Same root cache for all levels.
        owner,
        baseHierarchy: containerPath,
        outletName,
        outletArgs,
        showGhosts,
        isLoggingEnabled,
        createChildBlockFn,
      });
    }

    // Render visible blocks.
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
            processedChildren, // Pass pre-processed children for containers.
          },
          owner,
          createChildBlockFn
        )
      );
    } else if (showGhosts) {
      // Show ghost for invisible blocks in debug mode.
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
