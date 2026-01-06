import curryComponent from "ember-curry-component";
import {
  _setBlockDebugCallback,
  _setBlockLoggingCallback,
  _setBlockOutletBoundaryCallback,
  _setBlockOutletInfoComponent,
  _setCombinatorLogCallback,
  _setConditionLogCallback,
  _setEndGroupCallback,
  _setLoggerInterfaceCallback,
  _setOptionalMissingLogCallback,
  _setParamGroupLogCallback,
  _setRouteStateLogCallback,
  _setStartGroupCallback,
} from "discourse/lib/blocks/debug-hooks";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import devToolsState from "../state";
import BlockInfo from "./block-info";
import { blockDebugLogger } from "./debug-logger";
import GhostBlock from "./ghost-block";
import OutletInfo from "./outlet-info";

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
  // These bridge the main bundle to the debug logger in dev-tools

  // Callback for logging condition evaluations
  _setConditionLogCallback((opts) => {
    if (devToolsState.blockDebug) {
      blockDebugLogger.logCondition(opts);
    }
  });

  // Callback for updating combinator/condition results
  _setCombinatorLogCallback((opts) => {
    if (devToolsState.blockDebug) {
      if (opts.isCondition) {
        // Single condition result update
        blockDebugLogger.updateConditionResult(
          opts.type,
          opts.result,
          opts.depth
        );
      } else {
        // Combinator (AND/OR/NOT) result update
        blockDebugLogger.updateCombinatorResult(opts.result, opts.depth);
      }
    }
  });

  // Callback for logging param group matches
  _setParamGroupLogCallback((opts) => {
    if (devToolsState.blockDebug) {
      blockDebugLogger.logParamGroup(opts);
    }
  });

  // Callback for logging route state
  _setRouteStateLogCallback((opts) => {
    if (devToolsState.blockDebug) {
      blockDebugLogger.logRouteState(opts);
    }
  });

  // Callback for logging optional missing blocks
  _setOptionalMissingLogCallback((blockName, hierarchy) => {
    if (devToolsState.blockDebug) {
      blockDebugLogger.logOptionalMissing(blockName, hierarchy);
    }
  });

  // Callback for starting a logging group
  _setStartGroupCallback((blockName, hierarchy) => {
    if (devToolsState.blockDebug) {
      blockDebugLogger.startGroup(blockName, hierarchy);
    }
  });

  // Callback for ending a logging group
  _setEndGroupCallback((finalResult) => {
    if (devToolsState.blockDebug) {
      blockDebugLogger.endGroup(finalResult);
    }
  });

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
}
