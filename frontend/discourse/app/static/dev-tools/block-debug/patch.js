import curryComponent from "ember-curry-component";
import { _setBlockDebugCallback } from "discourse/components/block-outlet";
import blockDebugState from "discourse/lib/blocks/debug-state";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import BlockInfo from "./block-info";
import GhostBlock from "./ghost-block";

/**
 * Patches the block system to inject debug overlay components.
 *
 * When visual overlay is enabled, this callback wraps rendered blocks
 * with BlockInfo components and adds GhostBlock placeholders for
 * blocks that fail their conditions.
 */
export function patchBlockRendering() {
  _setBlockDebugCallback((blockData, context) => {
    if (!blockDebugState.visualOverlay) {
      return blockData;
    }

    const { name, Component, args, conditions, conditionsPassed } = blockData;
    const { outletName } = context;
    const owner = getOwnerWithFallback();

    // If conditions failed, return a ghost block
    if (conditionsPassed === false) {
      return {
        Component: curryComponent(
          GhostBlock,
          {
            blockName: name,
            outletName,
            conditions,
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
          outletName,
          blockArgs: args,
          conditions,
          WrappedComponent: Component,
        },
        owner
      ),
    };
  });
}
