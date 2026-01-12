import * as CoreBlocks from "discourse/blocks/core-blocks";
import { withPluginApi } from "discourse/lib/plugin-api";

/**
 * Registers core blocks from the registry.
 *
 * This initializer runs after "discourse-bootstrap" but before "freeze-block-registry"
 * to ensure core blocks are available before the registry is frozen.
 */
export default {
  after: "discourse-bootstrap",
  before: "freeze-block-registry",

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
