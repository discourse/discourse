import * as BuiltinBlocks from "discourse/blocks/builtin";
import { withPluginApi } from "discourse/lib/plugin-api";

/**
 * Registers built-in blocks from the registry.
 *
 * This initializer runs after "discourse-bootstrap" but before "freeze-block-registry"
 * to ensure built-in blocks are available before the registry is frozen.
 */
export default {
  after: "discourse-bootstrap",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      for (const BlockClass of Object.values(BuiltinBlocks)) {
        if (typeof BlockClass === "function" && BlockClass.blockName) {
          api.registerBlock(BlockClass);
        }
      }
    });
  },
};
