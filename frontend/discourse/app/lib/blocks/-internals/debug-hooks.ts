/**
 * Debug hooks for block dev-tools integration.
 *
 * This module provides:
 * - Debug callback hooks for dev-tools integration (visual overlays, logging, outlet boundaries)
 * - Ghost component creation for visualizing hidden blocks
 * - Debug console grouping utilities
 *
 * The debug hooks use TrackedMap for reactivity, enabling Ember's reactivity system
 * to trigger re-renders when callbacks are set/cleared.
 */
import type Component from "@glimmer/component";
import type Owner from "@ember/owner";
import { trackedMap } from "@ember/reactive/collections";
import { FAILURE_TYPE } from "discourse/lib/blocks/-internals/patterns";
import type {
  BlockClass,
  BlockEntry,
  ChildBlockResult,
} from "discourse/lib/blocks/-internals/types";

/**
 * Callback key constants for the debug hooks registry.
 * Use these instead of magic strings when calling debugHooks.getCallback/setCallback.
 */
export const DEBUG_CALLBACK = Object.freeze({
  BLOCK_DEBUG: "blockDebug",
  BLOCK_LOGGING: "blockLogging",
  VISUAL_OVERLAY: "visualOverlay",
  GHOST_BLOCKS: "ghostBlocks",
  OUTLET_INFO_COMPONENT: "outletInfoComponent",
  CONDITION_LOG: "conditionLog",
  COMBINATOR_LOG: "combinatorLog",
  CONDITION_RESULT: "conditionResult",
  PARAM_GROUP_LOG: "paramGroupLog",
  ROUTE_STATE_LOG: "routeStateLog",
  OPTIONAL_MISSING_LOG: "optionalMissingLog",
  START_GROUP: "startGroup",
  END_GROUP: "endGroup",
  LOGGER_INTERFACE: "loggerInterface",
  GHOST_CHILDREN_CREATOR: "ghostChildrenCreator",
  /**
   * Returns an object whose fields are merged into the condition
   * evaluator's per-block context. Lets external code (e.g. a user/viewport
   * simulation) inject extra context without coupling the blocks service to
   * those consumers. Read by the root
   * container's preprocessor on every visibility evaluation, so a
   * tracked source inside the callback propagates re-renders.
   *
   * Example payload: `{ simulation: { user, viewport } }`.
   */
  EVAL_CONTEXT: "evalContext",
  /**
   * Returns a boolean. When truthy, a container that normally reveals only
   * part of its content at a time (a paged or collapsed presentation) should
   * instead make ALL of its content reachable, and keep its navigation
   * interactive, so each part can be manipulated directly. Read on the live
   * render path, so a tracked source inside the callback propagates
   * re-renders. Left unset, containers render their normal presentation.
   */
  EDIT_PRESENTATION: "editPresentation",
});

/**
 * A debug callback registered by dev-tools. Callbacks vary in arity and
 * return shape depending on which `DEBUG_CALLBACK` key they're registered
 * under, so callers narrow the return value at the call site.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type DebugCallback = (...args: any[]) => unknown;

/**
 * The logger interface handed to conditions for logging, as returned by the
 * LOGGER_INTERFACE callback.
 */
export interface DebugLoggerInterface {
  logCondition: DebugCallback;
  updateCombinatorResult: DebugCallback;
  updateConditionResult: DebugCallback;
  logParamGroup: DebugCallback;
  logRouteState: DebugCallback;
}

/**
 * Singleton class that manages debug callback hooks for the block rendering system.
 * Uses TrackedMap for reactivity, so components accessing these values will re-render
 * when callbacks are set or cleared.
 */
class DebugHooks {
  /**
   * Tracked callback registry for debug hooks.
   * Using TrackedMap enables reactivity when callbacks are set/cleared.
   */
  #callbacks: Map<string, DebugCallback | null> = trackedMap<
    string,
    DebugCallback | null
  >(Object.values(DEBUG_CALLBACK).map((key): [string, null] => [key, null]));

  /**
   * Gets a debug callback from the registry.
   *
   * @param key - The callback key (use DEBUG_CALLBACK constants).
   * @returns The callback function, or null/undefined if not set.
   */
  getCallback(key: string): DebugCallback | null | undefined {
    return this.#callbacks.get(key);
  }

  /**
   * Sets a debug callback in the registry.
   * Used by dev-tools to register debug hooks.
   *
   * @param key - The callback key (use DEBUG_CALLBACK constants).
   * @param value - The callback function, or null to clear.
   * @throws If the key is not a valid callback key.
   */
  setCallback(key: string, value: DebugCallback | null): void {
    if (!this.#callbacks.has(key)) {
      const validKeys = Object.values(DEBUG_CALLBACK).join(", ");
      throw new Error(
        `[Blocks] Unknown debug callback key: "${key}". Valid keys are: ${validKeys}.`
      );
    }
    this.#callbacks.set(key, value);
  }

  /**
   * Returns whether console logging is enabled.
   * Convenience getter that invokes the blockLogging callback.
   *
   * @returns True if logging is enabled.
   */
  get isBlockLoggingEnabled(): boolean {
    return (
      (this.#callbacks.get(DEBUG_CALLBACK.BLOCK_LOGGING)?.() as
        | boolean
        | undefined) ?? false
    );
  }

  /**
   * Returns the outlet info component if outlet boundaries are enabled.
   * Invokes the OUTLET_INFO_COMPONENT callback which returns the component
   * when enabled, or a nullish value when disabled.
   *
   * @returns The outlet info component, or null.
   */
  get outletInfoComponent(): typeof Component | null | undefined {
    return this.#callbacks.get(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT)?.() as
      | typeof Component
      | null
      | undefined;
  }

  /**
   * Returns whether outlet boundaries should be shown.
   * Derived from whether the outlet info component is available.
   *
   * @returns True if boundaries should be shown.
   */
  get isOutletBoundaryEnabled(): boolean {
    return !!this.outletInfoComponent;
  }

  /**
   * Returns whether visual overlay is enabled.
   *
   * @returns True if visual overlay is enabled.
   */
  get isVisualOverlayEnabled(): boolean {
    return (
      (this.#callbacks.get(DEBUG_CALLBACK.VISUAL_OVERLAY)?.() as
        | boolean
        | undefined) ?? false
    );
  }

  /**
   * Returns whether ghost blocks are enabled.
   *
   * @returns True if ghost blocks are enabled.
   */
  get isGhostBlocksEnabled(): boolean {
    return (
      (this.#callbacks.get(DEBUG_CALLBACK.GHOST_BLOCKS)?.() as
        | boolean
        | undefined) ?? false
    );
  }

  /**
   * Returns whether content should be presented in its fully-revealed,
   * directly-editable form (see `EDIT_PRESENTATION`). A paged/collapsing
   * container reads this to expose all of its parts instead of one at a time.
   *
   * @returns
   */
  get isEditPresentation() {
    return this.#callbacks.get(DEBUG_CALLBACK.EDIT_PRESENTATION)?.() ?? false;
  }

  /**
   * Returns the logger interface for conditions to use.
   * Convenience getter that invokes the loggerInterface callback.
   *
   * The interface has methods: logCondition, updateCombinatorResult,
   * updateConditionResult, logParamGroup, logRouteState.
   *
   * @returns The logger interface, or null if not available.
   */
  get loggerInterface(): DebugLoggerInterface | null {
    return (
      (this.#callbacks.get(DEBUG_CALLBACK.LOGGER_INTERFACE)?.() as
        | DebugLoggerInterface
        | null
        | undefined) ?? null
    );
  }
}

/**
 * Singleton instance of DebugHooks.
 * Import this to access debug callbacks with tracked reactivity.
 */
export const debugHooks = new DebugHooks();

/**
 * Ghost component data produced by the BLOCK_DEBUG dev-tools callback, before
 * the caller attaches a stable rendering `key`.
 */
export type DebugGhostData = Omit<ChildBlockResult, "key">;

/**
 * Data describing a block to ghost, passed to the BLOCK_DEBUG callback.
 */
export interface DebugGhostBlockData {
  /** The block name. */
  name: string;
  /** The block's unique ID (if set). */
  id?: string;
  /** Stable unique key for this entry, forwarded into the debug payload so
   *  consumers can wire the ghost back to its underlying layout entry. */
  key?: string;
  /** Block arguments. */
  args?: Record<string, unknown>;
  /** Container arguments. */
  containerArgs?: Record<string, unknown>;
  /** Block conditions. */
  conditions?: BlockEntry["conditions"];
  /** Type of failure (from FAILURE_TYPE). */
  failureType?: string;
  /** Custom failure reason message. */
  failureReason?: string;
  /** Ghost children for containers. */
  children?: ChildBlockResult[] | null;
}

/**
 * Context passed to the BLOCK_DEBUG callback alongside the ghost block data.
 */
export interface DebugGhostContext {
  /** The outlet/hierarchy name for display. */
  outletName: string;
  /** Outlet arguments. */
  outletArgs?: Record<string, unknown>;
}

/**
 * Options for `handleOptionalMissingBlock()`.
 */
export interface HandleOptionalMissingBlockOptions {
  /** The name of the missing block. */
  blockName: string;
  /** The block entry. */
  entry: BlockEntry;
  /** The hierarchy path for logging. */
  hierarchy: string;
  /** Whether debug logging is enabled. */
  isLoggingEnabled: boolean;
  /** Whether to show ghost components. */
  showGhosts: boolean;
  /** Stable unique key for this block. */
  key: string;
}

/**
 * Handles an optional missing block by logging and optionally creating a ghost.
 *
 * When a block reference ends with `?` but the block is not registered, this
 * function handles the logging and ghost component creation.
 *
 * @returns Ghost component data with key if showGhosts is true, null otherwise.
 */
export function handleOptionalMissingBlock({
  blockName,
  entry,
  hierarchy,
  isLoggingEnabled,
  showGhosts,
  key,
}: HandleOptionalMissingBlockOptions): ChildBlockResult | null {
  // Log if debug logging is enabled
  if (isLoggingEnabled) {
    debugHooks.getCallback(DEBUG_CALLBACK.OPTIONAL_MISSING_LOG)?.(
      blockName,
      entry.id,
      hierarchy
    );
  }

  // Show ghost if ghost blocks are enabled
  if (showGhosts) {
    const ghostData = createDebugGhost(
      {
        name: blockName,
        id: entry.id,
        // Forward the stable key into the BLOCK_DEBUG payload so consumers
        // can wire the ghost back to its layout entry — see the matching
        // note in `handleUnknownBlock`. The same `key` is also stamped on
        // the returned ghostData below, which drives Glimmer's `{{#each}}`
        // identity.
        key,
        args: entry.args,
        conditions: entry.conditions,
        failureType: FAILURE_TYPE.OPTIONAL_MISSING,
      },
      { outletName: hierarchy }
    );
    return ghostData ? { ...ghostData, key } : null;
  }

  return null;
}

/**
 * Handles an unknown / unresolvable block reference (typo or
 * not-yet-installed plugin block, NOT the `?` opt-in optional-missing
 * case). In strict rendering this entry is silently skipped. When
 * `showGhosts` is enabled (e.g. dev-tools' overlay is on, or any
 * preview/edit context) the block renders as a labelled placeholder
 * via the existing ghost-block component so the author can see the
 * reference and replace it.
 *
 * @param options - The unknown-block descriptor. blockName is the string the
 *   author typed (or "(unknown)" when the entry's block was a non-string
 *   value); entry, hierarchy, and showGhosts describe the placeholder to
 *   render; key is a stable unique key for the entry; owner, outletArgs,
 *   isLoggingEnabled, containerPath, and resolveBlockFn are forwarded to the
 *   ghost-children creator.
 * @returns The ghost block data, or null when ghosts are disabled.
 */
export function handleUnknownBlock({
  blockName,
  entry,
  hierarchy,
  showGhosts,
  key,
  owner,
  outletArgs,
  isLoggingEnabled,
  containerPath,
  resolveBlockFn,
}) {
  if (!showGhosts) {
    return null;
  }

  // An unknown block carries no metadata, so we can't tell whether it was a
  // container. But if the saved layout gave it children it was authored as
  // one — surface them as nested ghosts (same mechanism resolved containers
  // use, see `createGhostBlock`) so the author can see and salvage the work
  // before removing the broken parent.
  let ghostChildren = null;
  if (entry.children?.length) {
    ghostChildren = debugHooks.getCallback(
      DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR
    )?.(
      entry.children,
      owner,
      containerPath,
      outletArgs,
      isLoggingEnabled,
      resolveBlockFn
    );
  }

  const ghostData = createDebugGhost(
    {
      name: blockName,
      id: entry.id,
      // Forward the stable key into the BLOCK_DEBUG payload so debug
      // consumers can wire the ghost back to its underlying layout
      // entry. The same `key`
      // is also stamped on the returned ghostData below — the
      // duplication is intentional: the outer key drives Glimmer's
      // `{{#each}}` identity, the inner one drives `BLOCK_DEBUG`
      // consumer logic.
      key,
      args: entry.args,
      conditions: entry.conditions,
      failureType: FAILURE_TYPE.UNKNOWN_BLOCK,
      failureReason: `Block "${blockName}" is not registered.`,
      children: ghostChildren,
    },
    { outletName: hierarchy }
  );
  return ghostData ? { ...ghostData, key } : null;
}

/**
 * Builds a container path for nested containers.
 *
 * Maintains a count map to ensure unique indices for containers of the same type.
 * For example, if there are two "group" containers without ids, they get paths like:
 * - `baseHierarchy/group[0]`
 * - `baseHierarchy/group[1]`
 *
 * If a block has an id, it replaces the index (since the id is unique):
 * - `baseHierarchy/group(#my-id)`
 *
 * @param blockName - The block name.
 * @param blockId - The block's unique id (if set).
 * @param baseHierarchy - The base hierarchy path.
 * @param containerCounts - Map tracking container counts.
 * @returns The full container path.
 */
export function buildContainerPath(
  blockName: string,
  blockId: string | null | undefined,
  baseHierarchy: string,
  containerCounts: Map<string, number>
): string {
  // Always increment the counter for consistent indexing of blocks without ids.
  const count = containerCounts.get(blockName) ?? 0;
  containerCounts.set(blockName, count + 1);

  // Use id if available (unique), otherwise fall back to index.
  const suffix = blockId ? `(#${blockId})` : `[${count}]`;
  return `${baseHierarchy}/${blockName}${suffix}`;
}

/**
 * Invokes the BLOCK_DEBUG callback to create a ghost component.
 *
 * This is the low-level helper that calls the debug callback with block data.
 * Used by both `createGhostBlock` (entry-processing time) and `asGhost`
 * (render time) to avoid duplicating the callback invocation logic.
 *
 * @param blockData - Data describing the block to ghost.
 * @param context - Context for the ghost.
 * @returns Ghost data with Component property, or null if callback
 *   not set or didn't return a component.
 */
export function createDebugGhost(
  blockData: DebugGhostBlockData,
  context: DebugGhostContext
): DebugGhostData | null {
  const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)?.(
    {
      ...blockData,
      Component: null,
      conditionsPassed: false,
    },
    context
  ) as DebugGhostData | undefined;

  return ghostData && ghostData.Component ? ghostData : null;
}

/**
 * A function that resolves a block reference (string name or class) to a
 * block class, an optional-missing marker, or null when unresolved. Used
 * here only as a value relayed to the GHOST_CHILDREN_CREATOR callback, not
 * called directly by this module.
 */
export type ResolveBlockFn = (blockRef: string | BlockClass) => unknown;

/**
 * Options for `createGhostBlock()`.
 */
export interface CreateGhostBlockOptions {
  /** The block name. */
  blockName: string;
  /** The block entry. */
  entry: BlockEntry;
  /** The hierarchy path for display. */
  hierarchy: string;
  /** Container path for child hierarchies. */
  containerPath?: string;
  /** Whether this block is a container. */
  isContainer: boolean;
  /** The application owner. */
  owner: Owner;
  /** Outlet arguments. */
  outletArgs?: Record<string, unknown>;
  /** Whether debug logging is enabled. */
  isLoggingEnabled: boolean;
  /** Function to resolve block references. */
  resolveBlockFn: ResolveBlockFn;
  /** Stable unique key for this block. */
  key: string;
}

/**
 * Creates a ghost component for an invisible block.
 *
 * Ghost components are shown in debug mode to visualize blocks that failed
 * their conditions or have no visible children.
 *
 * @returns Ghost component data with key if successful, null otherwise.
 */
export function createGhostBlock({
  blockName,
  entry,
  hierarchy,
  containerPath,
  isContainer,
  owner,
  outletArgs,
  isLoggingEnabled,
  resolveBlockFn,
  key,
}: CreateGhostBlockOptions): ChildBlockResult | null {
  // For container blocks with children that failed due to no visible children,
  // recursively create ghost children so they appear nested in the debug overlay.
  let ghostChildren: ChildBlockResult[] | null | undefined = null;
  if (
    isContainer &&
    entry.children?.length &&
    entry.__failureType === FAILURE_TYPE.NO_VISIBLE_CHILDREN
  ) {
    ghostChildren = debugHooks.getCallback(
      DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR
    )?.(
      entry.children,
      owner,
      containerPath,
      outletArgs,
      isLoggingEnabled,
      resolveBlockFn
    ) as ChildBlockResult[] | undefined;
  }

  const ghostData = createDebugGhost(
    {
      name: blockName,
      id: entry.id,
      // Forward the stable key into the BLOCK_DEBUG payload — see the
      // matching note in `handleUnknownBlock` for why this is needed.
      key,
      args: entry.args,
      containerArgs: entry.containerArgs,
      conditions: entry.conditions,
      failureType: entry.__failureType,
      failureReason: entry.__failureReason,
      children: ghostChildren,
    },
    { outletName: hierarchy }
  );

  return ghostData ? { ...ghostData, key } : null;
}

/**
 * Executes a function within a debug console group.
 * Ensures START_GROUP and END_GROUP callbacks are always paired.
 *
 * @param blockName - The block name for the group label.
 * @param blockId - The block's unique ID (if set).
 * @param hierarchy - The hierarchy path for context.
 * @param isLoggingEnabled - Whether debug logging is active.
 * @param fn - Function to execute that returns the condition result.
 * @returns The result of the function execution.
 */
export function withDebugGroup(
  blockName: string,
  blockId: string | null,
  hierarchy: string,
  isLoggingEnabled: boolean,
  fn: () => boolean
): boolean {
  if (!isLoggingEnabled) {
    return fn();
  }

  debugHooks.getCallback(DEBUG_CALLBACK.START_GROUP)?.(
    blockName,
    blockId,
    hierarchy
  );
  const result = fn();
  debugHooks.getCallback(DEBUG_CALLBACK.END_GROUP)?.(result);
  return result;
}
