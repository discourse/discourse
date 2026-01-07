import curryComponent from "ember-curry-component";
import { isContainerBlock } from "discourse/components/block-outlet";
import {
  _setBlockDebugCallback,
  _setBlockLoggingCallback,
  _setBlockOutletBoundaryCallback,
  _setBlockOutletInfoComponent,
  _setCombinatorLogCallback,
  _setConditionLogCallback,
  _setConditionResultCallback,
  _setEndGroupCallback,
  _setGhostChildrenCreator,
  _setLoggerInterfaceCallback,
  _setOptionalMissingLogCallback,
  _setParamGroupLogCallback,
  _setRouteStateLogCallback,
  _setStartGroupCallback,
  getBlockDebugCallback,
} from "discourse/lib/blocks/debug-hooks";
import { OPTIONAL_MISSING } from "discourse/lib/blocks/patterns";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import devToolsState from "../state";
import BlockInfo from "./block-info";
import { blockDebugLogger } from "./debug-logger";
import GhostBlock from "./ghost-block";
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
 * @param {Array<Object>} childConfigs - Child block configurations (already preprocessed with __visible)
 * @param {import("@ember/owner").default} owner - The application owner
 * @param {string} containerPath - The container's hierarchy path (e.g., "outlet/group[0]")
 * @param {Object} outletArgs - Outlet arguments for context
 * @param {boolean} isLoggingEnabled - Whether logging is enabled (unused, kept for API compatibility)
 * @param {Function} resolveBlockFn - Function to resolve block references to classes
 * @returns {Array<{Component: import("ember-curry-component").CurriedComponent}>} Array of ghost components
 */
function createGhostChildren(
  childConfigs,
  owner,
  containerPath,
  outletArgs,
  isLoggingEnabled,
  resolveBlockFn
) {
  const result = [];
  const containerCounts = new Map();

  for (const childConfig of childConfigs) {
    const resolvedBlock = resolveBlockFn(childConfig.block);

    // Handle optional missing block
    if (resolvedBlock?.optionalMissing === OPTIONAL_MISSING) {
      const ghostData = getBlockDebugCallback()(
        {
          name: resolvedBlock.name,
          Component: null,
          args: childConfig.args,
          conditions: childConfig.conditions,
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
    const isChildContainer = isContainerBlock(resolvedBlock);

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
      childConfig.children?.length &&
      childConfig.__failureReason === "no-visible-children"
    ) {
      nestedGhostChildren = createGhostChildren(
        childConfig.children,
        owner,
        nestedContainerPath,
        outletArgs,
        isLoggingEnabled,
        resolveBlockFn
      );
    }

    const ghostData = getBlockDebugCallback()(
      {
        name: blockName,
        Component: null,
        args: childConfig.args,
        conditions: childConfig.conditions,
        conditionsPassed: false,
        failureReason: childConfig.__failureReason,
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
  _setBlockDebugCallback((blockData, context) => {
    // Check state at invocation time (devToolsState is captured in closure)
    if (!devToolsState.blockVisualOverlay) {
      return blockData;
    }

    const {
      name,
      Component,
      args,
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
          conditions,
          outletArgs: context.outletArgs,
          WrappedComponent: Component,
        },
        owner
      ),
    };
  });

  // Callback for console logging
  _setBlockLoggingCallback(() => devToolsState.blockDebug);
  // Callback for outlet boundaries
  _setBlockOutletBoundaryCallback(() => devToolsState.blockOutletBoundaries);
  // Component for outlet info tooltip
  _setBlockOutletInfoComponent(OutletInfo);

  // === Logging Callbacks ===
  // These bridge the main bundle to the debug logger in dev-tools.
  // All use makeDebugCallback to centralize the devToolsState.blockDebug check.

  // Callback for logging condition evaluations (before result is known)
  _setConditionLogCallback(
    makeDebugCallback((opts) => {
      blockDebugLogger.logCondition(opts);
    })
  );

  // Callback for updating combinator (AND/OR/NOT) results
  _setCombinatorLogCallback(
    makeDebugCallback((opts) => {
      blockDebugLogger.updateCombinatorResult(opts.conditionSpec, opts.result);
    })
  );

  // Callback for updating single condition results
  _setConditionResultCallback(
    makeDebugCallback((opts) => {
      blockDebugLogger.updateConditionResult(opts.conditionSpec, opts.result);
    })
  );

  // Callback for logging param group matches
  _setParamGroupLogCallback(
    makeDebugCallback((opts) => {
      blockDebugLogger.logParamGroup(opts);
    })
  );

  // Callback for logging route state
  _setRouteStateLogCallback(
    makeDebugCallback((opts) => {
      blockDebugLogger.logRouteState(opts);
    })
  );

  // Callback for logging optional missing blocks
  _setOptionalMissingLogCallback(
    makeDebugCallback((blockName, hierarchy) => {
      blockDebugLogger.logOptionalMissing(blockName, hierarchy);
    })
  );

  // Callback for starting a logging group
  _setStartGroupCallback(
    makeDebugCallback((blockName, hierarchy) => {
      blockDebugLogger.startGroup(blockName, hierarchy);
    })
  );

  // Callback for ending a logging group
  _setEndGroupCallback(
    makeDebugCallback((finalResult) => {
      blockDebugLogger.endGroup(finalResult);
    })
  );

  // Callback that returns the logger interface for conditions
  _setLoggerInterfaceCallback(() => {
    if (!devToolsState.blockDebug) {
      return null;
    }
    return {
      logCondition: (opts) => blockDebugLogger.logCondition(opts),
      updateCombinatorResult: (result, depth) =>
        blockDebugLogger.updateCombinatorResult(result, depth),
      logParamGroup: (opts) => blockDebugLogger.logParamGroup(opts),
      logRouteState: (opts) => blockDebugLogger.logRouteState(opts),
    };
  });

  // Register the ghost children creator function
  _setGhostChildrenCreator(createGhostChildren);
}
