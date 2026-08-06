import type Owner from "@ember/owner";
import curryComponent from "ember-curry-component";
import {
  DEBUG_CALLBACK,
  type DebugGhostBlockData,
  type DebugGhostContext,
  type DebugGhostData,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import {
  FAILURE_TYPE,
  isOptionalMissing,
  MAX_LAYOUT_DEPTH,
  type OptionalMissingMarker,
} from "discourse/lib/blocks/-internals/patterns";
import type {
  BlockClass,
  BlockComponent,
  BlockEntry,
} from "discourse/lib/blocks/-internals/types";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import devToolsState from "../state";
import BlockInfo from "./block-info";
import { blockDebugLogger } from "./debug-logger";
import GhostBlock from "./ghost-block";
import OutletInfo from "./outlet-info";

/**
 * A function that resolves a block reference (string name or class) to a
 * block class, an optional-missing marker, or null when unresolved. Matches
 * the real contract of `tryResolveBlock()`, the only implementation ever
 * passed in (see `entry-processing.ts`).
 */
type ResolveBlockFn = (
  blockRef: string | BlockClass
) => BlockClass | OptionalMissingMarker | null;

/**
 * The block data passed to the BLOCK_DEBUG callback: `DebugGhostBlockData`
 * plus the fields every caller (the render pipeline and `createDebugGhost()`)
 * always adds on top before invoking the callback.
 */
interface BlockDebugCallbackData extends DebugGhostBlockData {
  Component: BlockComponent | null;
  conditionsPassed: boolean;
}

/**
 * Creates a wrapper callback that only executes when block debug is enabled.
 *
 * This factory eliminates the repeated `if (devToolsState.blockDebug)` checks
 * across all logging callbacks.
 *
 * @param fn - The callback function to wrap.
 * @returns A wrapper that calls `fn` only when debug is enabled.
 */
function makeDebugCallback<Args extends unknown[]>(
  fn: (...args: Args) => void
): (...args: Args) => void {
  return (...args: Args) => {
    if (devToolsState.blockDebug) {
      fn(...args);
    }
  };
}

/**
 * Creates ghost components for children of a container ghost block.
 *
 * When a container block is rendered as a ghost (due to no visible children),
 * this function recursively processes its children to create ghost components
 * so they appear nested inside the container ghost in the debug overlay.
 *
 * Includes a depth limit as defense-in-depth against stack overflow. The primary
 * protection is validation-time depth checking in `validateLayout`, but this
 * provides additional safety during ghost rendering.
 *
 * @param childEntries - Child layout entries (already preprocessed with __visible and __failureType)
 * @param owner - The application owner
 * @param containerPath - The container's hierarchy path (e.g., "outlet/group[0]")
 * @param outletArgs - Outlet arguments for context
 * @param isLoggingEnabled - Whether logging is enabled (unused, kept for API compatibility)
 * @param resolveBlockFn - Function to resolve block references to classes
 * @param depth - Current nesting depth for recursion limit checking.
 * @returns Array of ghost component data
 */
function createGhostChildren(
  childEntries: BlockEntry[],
  owner: Owner,
  containerPath: string,
  outletArgs: Record<string, unknown> | undefined,
  isLoggingEnabled: boolean,
  resolveBlockFn: ResolveBlockFn,
  depth = 0
): DebugGhostData[] {
  // Defense-in-depth: silently stop recursion if depth exceeds limit.
  // Primary validation happens at layout validation time in validateLayout().
  if (depth >= MAX_LAYOUT_DEPTH) {
    return [];
  }

  const result: DebugGhostData[] = [];
  const containerCounts = new Map<string, number>();

  for (const childEntry of childEntries) {
    const resolvedBlock = resolveBlockFn(childEntry.block);

    // Handle optional missing block
    if (isOptionalMissing(resolvedBlock)) {
      const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)?.(
        {
          name: resolvedBlock.name,
          id: childEntry.id,
          Component: null,
          args: childEntry.args,
          containerArgs: childEntry.containerArgs,
          conditions: childEntry.conditions,
          conditionsPassed: false,
          failureType: FAILURE_TYPE.OPTIONAL_MISSING,
        },
        { outletName: containerPath }
      ) as DebugGhostData | undefined;
      if (ghostData?.Component) {
        result.push(ghostData);
      }
      continue;
    }

    // Skip unresolved blocks
    if (!resolvedBlock) {
      continue;
    }

    const blockMeta = getBlockMetadata(resolvedBlock);
    const blockName = blockMeta?.blockName || "unknown";
    const isChildContainer = blockMeta?.isContainer ?? false;

    // Build container path for nested containers.
    // Use id if available (unique), otherwise fall back to index.
    let nestedContainerPath: string | undefined;
    if (isChildContainer) {
      const count = containerCounts.get(blockName) ?? 0;
      containerCounts.set(blockName, count + 1);
      const suffix = childEntry.id ? `(#${childEntry.id})` : `[${count}]`;
      nestedContainerPath = `${containerPath}/${blockName}${suffix}`;
    }

    // Recursively create ghost children for nested containers
    let nestedGhostChildren: DebugGhostData[] | null = null;
    if (
      isChildContainer &&
      childEntry.children?.length &&
      childEntry.__failureType === FAILURE_TYPE.NO_VISIBLE_CHILDREN
    ) {
      nestedGhostChildren = createGhostChildren(
        childEntry.children,
        owner,
        // `isChildContainer` guarantees this was set above.
        nestedContainerPath as string,
        outletArgs,
        isLoggingEnabled,
        resolveBlockFn,
        depth + 1
      );
    }

    const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)?.(
      {
        name: blockName,
        id: childEntry.id,
        Component: null,
        args: childEntry.args,
        containerArgs: childEntry.containerArgs,
        conditions: childEntry.conditions,
        conditionsPassed: false,
        failureType: childEntry.__failureType,
        failureReason: childEntry.__failureReason, // Optional custom message
        children: nestedGhostChildren,
      },
      { outletName: containerPath }
    ) as DebugGhostData | undefined;
    if (ghostData?.Component) {
      result.push(ghostData);
    }
  }

  return result;
}

/**
 * Patches the block system to inject debug overlay components.
 *
 * When visual overlay is enabled, this callback wraps rendered blocks
 * with BlockInfo components and adds GhostBlock placeholders for
 * blocks that fail their conditions.
 *
 * Uses devToolsState via closure to check state at invocation time,
 * following the same pattern as plugin-outlet-debug.
 */
export function patchBlockRendering(): void {
  // Callback for visual overlay and ghost blocks - wraps blocks with debug info
  debugHooks.setCallback(
    DEBUG_CALLBACK.BLOCK_DEBUG,
    (blockData: BlockDebugCallbackData, context: DebugGhostContext) => {
      const showVisualOverlay = devToolsState.blockVisualOverlay;
      const showGhostBlocks = devToolsState.blockGhostBlocks;

      // Check state at invocation time (devToolsState is captured in closure)
      if (!showVisualOverlay && !showGhostBlocks) {
        return blockData;
      }

      const {
        name,
        id,
        Component,
        args,
        containerArgs,
        conditions,
        conditionsPassed,
        failureType,
        failureReason,
        children,
      } = blockData;
      const { outletName } = context;
      const owner = getOwnerWithFallback() as Owner;

      // If conditions failed, return a ghost block (if ghost blocks enabled)
      if (conditionsPassed === false) {
        if (!showGhostBlocks) {
          return blockData;
        }

        // Not typed as `DebugGhostData`/`ChildBlockResult`: this object is
        // self-referential (`asGhost` returns itself), and it's missing the
        // `key` that `ChildBlockResult` requires — the caller (`createGhostBlock()`
        // / `handleOptionalMissingBlock()`) attaches `key` after this callback
        // returns. Left for TS to infer structurally, same as the block-outlet
        // module's equivalent (real, keyed) ghost-of-a-ghost pattern.
        const ghostResult = {
          Component: curryComponent(
            GhostBlock,
            {
              blockName: name,
              blockId: id,
              // Use debugLocation to avoid being overwritten by template's @outletName
              debugLocation: outletName,
              blockArgs: args,
              containerArgs,
              conditions,
              failureType,
              failureReason,
              // Children are ghost components for container blocks with no visible children
              children,
            },
            owner
          ) as BlockComponent,
          isGhost: true,
          // No-op: calling asGhost on a ghost returns itself
          asGhost: () => ghostResult,
        };
        return ghostResult;
      }

      // Wrap the rendered block with debug info (if visual overlay enabled)
      if (!showVisualOverlay) {
        return blockData;
      }

      return {
        Component: curryComponent(
          BlockInfo,
          {
            blockName: name,
            blockId: id,
            // Use debugLocation to avoid being overwritten by template's @outletName
            debugLocation: outletName,
            blockArgs: args,
            containerArgs,
            conditions,
            outletArgs: context.outletArgs,
            WrappedComponent: Component,
          },
          owner
        ) as BlockComponent,
      };
    }
  );

  // Callback for console logging
  debugHooks.setCallback(
    DEBUG_CALLBACK.BLOCK_LOGGING,
    () => devToolsState.blockDebug
  );
  // Callback for visual overlay
  debugHooks.setCallback(
    DEBUG_CALLBACK.VISUAL_OVERLAY,
    () => devToolsState.blockVisualOverlay
  );
  // Callback for ghost blocks
  debugHooks.setCallback(
    DEBUG_CALLBACK.GHOST_BLOCKS,
    () => devToolsState.blockGhostBlocks
  );
  // Callback for outlet info component - returns the component when enabled, null otherwise.
  debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT, () =>
    devToolsState.blockOutletBoundaries ? OutletInfo : null
  );

  /* Logging Callbacks */
  // These bridge the main bundle to the debug logger in dev-tools.
  // All use makeDebugCallback to centralize the devToolsState.blockDebug check.

  // Callback for logging condition evaluations
  debugHooks.setCallback(
    DEBUG_CALLBACK.CONDITION_LOG,
    makeDebugCallback(
      (opts: Parameters<typeof blockDebugLogger.logCondition>[0]) => {
        blockDebugLogger.logCondition(opts);
      }
    )
  );

  // Callback for updating combinator (AND/OR/NOT) results
  debugHooks.setCallback(
    DEBUG_CALLBACK.COMBINATOR_LOG,
    makeDebugCallback(
      (opts: { conditionSpec: object | null | undefined; result: boolean }) => {
        blockDebugLogger.updateCombinatorResult(
          opts.conditionSpec,
          opts.result
        );
      }
    )
  );

  // Callback for updating single condition results
  debugHooks.setCallback(
    DEBUG_CALLBACK.CONDITION_RESULT,
    makeDebugCallback(
      (opts: { conditionSpec: object | null | undefined; result: boolean }) => {
        blockDebugLogger.updateConditionResult(opts.conditionSpec, opts.result);
      }
    )
  );

  // Callback for logging param group matches
  debugHooks.setCallback(
    DEBUG_CALLBACK.PARAM_GROUP_LOG,
    makeDebugCallback(
      (opts: Parameters<typeof blockDebugLogger.logParamGroup>[0]) => {
        blockDebugLogger.logParamGroup(opts);
      }
    )
  );

  // Callback for logging route state
  debugHooks.setCallback(
    DEBUG_CALLBACK.ROUTE_STATE_LOG,
    makeDebugCallback(
      (opts: Parameters<typeof blockDebugLogger.logRouteState>[0]) => {
        blockDebugLogger.logRouteState(opts);
      }
    )
  );

  // Callback for logging optional missing blocks
  debugHooks.setCallback(
    DEBUG_CALLBACK.OPTIONAL_MISSING_LOG,
    makeDebugCallback(
      (blockName: string, blockId: string | null, hierarchy: string) => {
        blockDebugLogger.logOptionalMissing(blockName, blockId, hierarchy);
      }
    )
  );

  // Callback for starting a logging group
  debugHooks.setCallback(
    DEBUG_CALLBACK.START_GROUP,
    makeDebugCallback(
      (blockName: string, blockId: string | null, hierarchy: string) => {
        blockDebugLogger.startGroup(blockName, blockId, hierarchy);
      }
    )
  );

  // Callback for ending a logging group
  debugHooks.setCallback(
    DEBUG_CALLBACK.END_GROUP,
    makeDebugCallback((finalResult: boolean) => {
      blockDebugLogger.endGroup(finalResult);
    })
  );

  // Callback that returns the logger interface for conditions
  debugHooks.setCallback(DEBUG_CALLBACK.LOGGER_INTERFACE, () => {
    if (!devToolsState.blockDebug) {
      return null;
    }
    return {
      logCondition: (
        opts: Parameters<typeof blockDebugLogger.logCondition>[0]
      ) => blockDebugLogger.logCondition(opts),
      updateCombinatorResult: (
        conditionSpec: object | null | undefined,
        result: boolean
      ) => blockDebugLogger.updateCombinatorResult(conditionSpec, result),
      updateConditionResult: (
        conditionSpec: object | null | undefined,
        result: boolean
      ) => blockDebugLogger.updateConditionResult(conditionSpec, result),
      logParamGroup: (
        opts: Parameters<typeof blockDebugLogger.logParamGroup>[0]
      ) => blockDebugLogger.logParamGroup(opts),
      logRouteState: (
        opts: Parameters<typeof blockDebugLogger.logRouteState>[0]
      ) => blockDebugLogger.logRouteState(opts),
    };
  });

  // Register the ghost children creator function
  debugHooks.setCallback(
    DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR,
    createGhostChildren
  );
}
