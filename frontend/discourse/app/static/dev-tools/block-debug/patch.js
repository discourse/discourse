// @ts-check
import curryComponent from "ember-curry-component";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { _isContainerBlock } from "discourse/lib/blocks/-internals/decorator";
import {
  MAX_LAYOUT_DEPTH,
  OPTIONAL_MISSING,
} from "discourse/lib/blocks/-internals/patterns";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import devToolsState from "../state";
/** @type {import("./block-info.gjs").default} */
import BlockInfo from "./block-info";
import { blockDebugLogger } from "./debug-logger";
/** @type {import("./ghost-block.gjs").default} */
import GhostBlock from "./ghost-block";
/** @type {import("./outlet-info.gjs").default} */
import OutletInfo from "./outlet-info";

/**
 * Creates a wrapper callback that only executes when block debug is enabled.
 *
 * This factory eliminates the repeated `if (devToolsState.blockDebug)` checks
 * across all logging callbacks.
 *
 * @param {Function} fn - The callback function to wrap.
 * @returns {Function} A wrapper that calls `fn` only when debug is enabled.
 */
function makeDebugCallback(fn) {
  return (...args) => {
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
 * @param {Array<Object>} childEntries - Child layout entries (already preprocessed with __visible)
 * @param {import("@ember/owner").default} owner - The application owner
 * @param {string} containerPath - The container's hierarchy path (e.g., "outlet/group[0]")
 * @param {Object} outletArgs - Outlet arguments for context
 * @param {boolean} isLoggingEnabled - Whether logging is enabled (unused, kept for API compatibility)
 * @param {Function} resolveBlockFn - Function to resolve block references to classes
 * @param {number} [depth=0] - Current nesting depth for recursion limit checking.
 * @returns {Array<{Component: import("ember-curry-component").CurriedComponent}>} Array of ghost components
 */
function createGhostChildren(
  childEntries,
  owner,
  containerPath,
  outletArgs,
  isLoggingEnabled,
  resolveBlockFn,
  depth = 0
) {
  // Defense-in-depth: silently stop recursion if depth exceeds limit.
  // Primary validation happens at layout validation time in validateLayout().
  if (depth >= MAX_LAYOUT_DEPTH) {
    return [];
  }

  const result = [];
  const containerCounts = new Map();

  for (const childEntry of childEntries) {
    const resolvedBlock = resolveBlockFn(childEntry.block);

    // Handle optional missing block
    if (resolvedBlock?.optionalMissing === OPTIONAL_MISSING) {
      const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)?.(
        {
          name: resolvedBlock.name,
          Component: null,
          args: childEntry.args,
          containerArgs: childEntry.containerArgs,
          conditions: childEntry.conditions,
          conditionsPassed: false,
          optionalMissing: true,
        },
        { outletName: containerPath }
      );
      if (ghostData?.Component) {
        result.push(ghostData);
      }
      continue;
    }

    // Skip unresolved blocks
    if (!resolvedBlock) {
      continue;
    }

    const blockName = resolvedBlock.blockName || "unknown";
    const isChildContainer = _isContainerBlock(resolvedBlock);

    // Build container path for nested containers
    let nestedContainerPath;
    if (isChildContainer) {
      const count = containerCounts.get(blockName) ?? 0;
      containerCounts.set(blockName, count + 1);
      nestedContainerPath = `${containerPath}/${blockName}[${count}]`;
    }

    // Recursively create ghost children for nested containers
    let nestedGhostChildren = null;
    if (
      isChildContainer &&
      childEntry.children?.length &&
      childEntry.__failureReason === "no-visible-children"
    ) {
      nestedGhostChildren = createGhostChildren(
        childEntry.children,
        owner,
        nestedContainerPath,
        outletArgs,
        isLoggingEnabled,
        resolveBlockFn,
        depth + 1
      );
    }

    const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)?.(
      {
        name: blockName,
        Component: null,
        args: childEntry.args,
        containerArgs: childEntry.containerArgs,
        conditions: childEntry.conditions,
        conditionsPassed: false,
        failureReason: childEntry.__failureReason,
        children: nestedGhostChildren,
      },
      { outletName: containerPath }
    );
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
export function patchBlockRendering() {
  // Callback for visual overlay - wraps blocks with debug info
  debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData, context) => {
    // Check state at invocation time (devToolsState is captured in closure)
    if (!devToolsState.blockVisualOverlay) {
      return blockData;
    }

    const {
      name,
      Component,
      args,
      containerArgs,
      conditions,
      conditionsPassed,
      optionalMissing,
      failureReason,
      children,
    } = blockData;
    const { outletName } = context;
    const owner = getOwnerWithFallback();

    // If conditions failed or block is optional and missing, return a ghost block
    if (conditionsPassed === false || optionalMissing) {
      return {
        Component: curryComponent(
          GhostBlock,
          {
            blockName: name,
            // Use debugLocation to avoid being overwritten by template's @outletName
            debugLocation: outletName,
            blockArgs: args,
            containerArgs,
            conditions,
            optionalMissing,
            failureReason,
            // Children are ghost components for container blocks with no visible children
            children,
          },
          owner
        ),
        isGhost: true,
      };
    }

    // Wrap the rendered block with debug info
    return {
      Component: curryComponent(
        BlockInfo,
        {
          blockName: name,
          // Use debugLocation to avoid being overwritten by template's @outletName
          debugLocation: outletName,
          blockArgs: args,
          containerArgs,
          conditions,
          outletArgs: context.outletArgs,
          WrappedComponent: Component,
        },
        owner
      ),
    };
  });

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
  // Callback for outlet info component - returns the component when enabled, null otherwise.
  debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT, () =>
    devToolsState.blockOutletBoundaries ? OutletInfo : null
  );

  // === Logging Callbacks ===
  // These bridge the main bundle to the debug logger in dev-tools.
  // All use makeDebugCallback to centralize the devToolsState.blockDebug check.

  // Callback for logging condition evaluations
  debugHooks.setCallback(
    DEBUG_CALLBACK.CONDITION_LOG,
    makeDebugCallback((opts) => {
      blockDebugLogger.logCondition(opts);
    })
  );

  // Callback for updating combinator (AND/OR/NOT) results
  debugHooks.setCallback(
    DEBUG_CALLBACK.COMBINATOR_LOG,
    makeDebugCallback((opts) => {
      blockDebugLogger.updateCombinatorResult(opts.conditionSpec, opts.result);
    })
  );

  // Callback for updating single condition results
  debugHooks.setCallback(
    DEBUG_CALLBACK.CONDITION_RESULT,
    makeDebugCallback((opts) => {
      blockDebugLogger.updateConditionResult(opts.conditionSpec, opts.result);
    })
  );

  // Callback for logging param group matches
  debugHooks.setCallback(
    DEBUG_CALLBACK.PARAM_GROUP_LOG,
    makeDebugCallback((opts) => {
      blockDebugLogger.logParamGroup(opts);
    })
  );

  // Callback for logging route state
  debugHooks.setCallback(
    DEBUG_CALLBACK.ROUTE_STATE_LOG,
    makeDebugCallback((opts) => {
      blockDebugLogger.logRouteState(opts);
    })
  );

  // Callback for logging optional missing blocks
  debugHooks.setCallback(
    DEBUG_CALLBACK.OPTIONAL_MISSING_LOG,
    makeDebugCallback((blockName, hierarchy) => {
      blockDebugLogger.logOptionalMissing(blockName, hierarchy);
    })
  );

  // Callback for starting a logging group
  debugHooks.setCallback(
    DEBUG_CALLBACK.START_GROUP,
    makeDebugCallback((blockName, hierarchy) => {
      blockDebugLogger.startGroup(blockName, hierarchy);
    })
  );

  // Callback for ending a logging group
  debugHooks.setCallback(
    DEBUG_CALLBACK.END_GROUP,
    makeDebugCallback((finalResult) => {
      blockDebugLogger.endGroup(finalResult);
    })
  );

  // Callback that returns the logger interface for conditions
  debugHooks.setCallback(DEBUG_CALLBACK.LOGGER_INTERFACE, () => {
    if (!devToolsState.blockDebug) {
      return null;
    }
    return {
      logCondition: (opts) => blockDebugLogger.logCondition(opts),
      updateCombinatorResult: (conditionSpec, result) =>
        blockDebugLogger.updateCombinatorResult(conditionSpec, result),
      updateConditionResult: (conditionSpec, result) =>
        blockDebugLogger.updateConditionResult(conditionSpec, result),
      logParamGroup: (opts) => blockDebugLogger.logParamGroup(opts),
      logRouteState: (opts) => blockDebugLogger.logRouteState(opts),
    };
  });

  // Register the ghost children creator function
  debugHooks.setCallback(
    DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR,
    createGhostChildren
  );
}
