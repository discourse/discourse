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
import type {
  BlockClass,
  BlockEntry,
  ChildBlockResult,
} from "discourse/lib/blocks/-internals/types";
import { shallowArgsEqual } from "discourse/lib/blocks/-internals/utils";

/**
 * A mutable, tracked box holding a cached container's current children. The
 * container's curry reads `current` reactively, so refreshing it in place lets
 * a cached container reflect new or removed children without being re-curried.
 */
interface ChildrenHolder {
  current: ChildBlockResult[] | undefined;
}

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

  /** Whether the block is a container (it gets a children holder). */
  isContainer?: boolean;

  /** Pre-processed children for container blocks. */
  processedChildren?: ChildBlockResult[];

  /**
   * The tracked children box threaded into a container's curry, so later
   * renders refresh its children in place rather than re-currying.
   */
  childrenHolder?: ChildrenHolder;
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

/** A cached block entry, keyed by the block's stable key. */
interface CacheEntry {
  ComponentClass: BlockClass;
  args?: Record<string, unknown>;
  containerArgs?: Record<string, unknown>;
  displayHierarchy?: string;
  containerPath?: string;
  debugWrapKey?: string;
  holder?: ChildrenHolder;
  result: ChildBlockResult;
}

export type LeafCache = Map<string, CacheEntry>;

/**
 * Gets or creates a curried component for a block, using the cache when
 * possible.
 *
 * Both leaf and container blocks are cached, keyed by their stable block key.
 * Caching the curried component preserves its identity across renders, so the
 * keyed each-loop that renders it keeps the same component instance (and its
 * DOM subtree) instead of tearing it down and remounting. This matters most for
 * containers: re-currying a container produces a new component value, which
 * forces a full remount of its subtree, including any children that load data,
 * on every structural change anywhere in the outlet.
 *
 * Containers do not bake their children into the curry. Instead the cache holds
 * a tracked holder whose `current` value is the freshly processed children; the
 * curry reads `holder.current` reactively, so a cached container reflects new or
 * removed children without being recreated.
 *
 * Cache hit conditions:
 *
 * 1. The component class is the same reference.
 * 2. The own args are shallowly equal.
 * 3. The `containerArgs` reference is identical. It is read by the parent
 *    container as a one-shot snapshot, so a replaced reference (e.g. a grid
 *    placement edit) must produce a fresh result.
 * 4. The hierarchy (`displayHierarchy`/`containerPath`) is unchanged. Both are
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
 * @param cache - The component cache keyed by stable block keys.
 * @param entry - The block entry with `__stableKey` and optional children.
 * @param resolvedBlock - The resolved block component class.
 * @param debugContext - Rendering context for this entry. See {@link DebugContext}.
 * @param owner - The application owner for service lookup.
 * @param createChildBlockFn - Creates child block components (injected from block-outlet).
 * @returns The cached or newly created component data.
 */
function getOrCreateBlockComponent(
  cache: LeafCache,
  entry: BlockEntry,
  resolvedBlock: BlockClass,
  debugContext: DebugContext,
  owner: Owner,
  createChildBlockFn: CreateChildBlockFn
): ChildBlockResult {
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
    // the wrapper or re-run the debug callback here: instance survival depends
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
  // starts empty pick up its first child on a later edit: without it, an empty
  // container would bake a static `undefined` children value and never update.
  const holder: ChildrenHolder | undefined = debugContext.isContainer
    ? trackedObject<ChildrenHolder>({ current: debugContext.processedChildren })
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
      // Use the canonical `${name}:${__stableKey}` key (the same shape resolved
      // blocks get below). This key is forwarded into the BLOCK_DEBUG payload,
      // where consumers use it to correlate the ghost back to its layout entry.
      // A categorising prefix here would make those lookups (selection, removal)
      // miss.
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
    //   1. Async factory still resolving. Common at boot; the trackedMap will
    //      re-evaluate this getter once the factory lands.
    //   2. Truly unknown block (typo in a saved layout, plugin not installed,
    //      etc.). Strict rendering silently skips these. When `showGhosts` is
    //      enabled, the author sees a labelled placeholder and can swap or
    //      remove the entry.
    if (!resolvedBlock) {
      if (showGhosts) {
        const blockName =
          typeof entry.block === "string" ? entry.block : "(unknown)";
        const stableKey = entry.__stableKey ?? "no-key";
        // When the unknown entry has children it was authored as a container;
        // give it a path so its ghost children get distinct hierarchies/keys
        // from any sibling unknown container. This also consumes a slot in the
        // same counting space as resolved containers, keeping sibling indices
        // stable.
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
          // Canonical `${name}:${__stableKey}` key. See the matching note in
          // the optional-missing branch above. Consumers correlate the ghost
          // back to its layout entry by this key, so it must not carry a
          // categorising prefix.
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
    //
    // A block that declares a `parts` composition and supplies no children of
    // its own renders those parts: they are synthesized into render-only child
    // entries here (never persisted). A part that is itself a composition
    // re-synthesizes on the next recursion level, so nesting needs no special
    // casing. An entry that supplies its own children bypasses the composition
    // and renders as a plain container.
    let childEntries: BlockEntry[] | undefined;
    if (isContainer && entry.children?.length) {
      childEntries = entry.children;
    } else if (isContainer && blockMeta?.parts && entry.children == null) {
      // Composed: a `parts` block with no `children` of its own renders its
      // composition. An entry that supplies its own `children` array, even an
      // empty one, bypasses the composition and renders as a plain container.
      // `synthesizePartEntries` is a JS helper; its metadata param is proven
      // present by the guard above, and its render-only entries are threaded
      // straight back into this same walk.
      childEntries = synthesizePartEntries(
        entry,
        blockMeta as Parameters<typeof synthesizePartEntries>[1]
      ) as BlockEntry[];
    }

    let processedChildren: ChildBlockResult[] | undefined;
    if (childEntries?.length) {
      processedChildren = processBlockEntries({
        entries: childEntries,
        cache, // Same root cache for all levels.
        owner,
        baseHierarchy: containerPath!,
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
