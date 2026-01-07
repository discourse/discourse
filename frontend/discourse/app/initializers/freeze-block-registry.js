import { _freezeBlockRegistry } from "discourse/lib/blocks/registration";

/**
 * Freezes the block registry, preventing new block registrations.
 *
 * This initializer runs early in the boot sequence (after discourse-bootstrap,
 * before inject-discourse-objects) to establish a clear boundary:
 *
 * - **Before freeze**: Plugins/themes register blocks in pre-initializers
 * - **After freeze**: Plugins/themes configure layouts with renderBlocks()
 *
 * This mirrors the transformer system's freeze-valid-transformers pattern.
 */
export default {
  before: "inject-discourse-objects",
  after: "discourse-bootstrap",

  initialize() {
    _freezeBlockRegistry();
  },
};
