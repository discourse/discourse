import * as CoreBlocks from "discourse/blocks/core-blocks";
import { withPluginApi } from "discourse/lib/plugin-api";

/**
 * Registers core blocks from the registry.
 *
 * This runs after all modules are loaded, safely avoiding the circular
 * dependency between block-outlet.gjs and registration.js.
 */
export default {
  initialize() {
    withPluginApi((api) => {
      for (const BlockClass of Object.values(CoreBlocks)) {
        if (typeof BlockClass === "function" && BlockClass.blockName) {
          api.registerBlock(BlockClass);
        }
      }
    });
  },
};
