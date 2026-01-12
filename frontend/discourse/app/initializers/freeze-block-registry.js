import {
  _freezeBlockRegistry,
  _freezeConditionTypeRegistry,
  _freezeOutletRegistry,
} from "discourse/lib/blocks/registration";

/**
 * Freezes the block, outlet, and condition type registries, preventing new registrations.
 *
 * This initializer runs early in the boot sequence (after discourse-bootstrap,
 * before inject-discourse-objects) to establish a clear boundary:
 *
 * - **Before freeze**: Plugins/themes register blocks, outlets, and condition types in pre-initializers
 * - **After freeze**: Plugins/themes configure layouts with renderBlocks()
 *
 * This mirrors the transformer system's freeze-valid-transformers pattern.
 */
export default {
  before: "inject-discourse-objects",
  after: "discourse-bootstrap",

  initialize() {
    _freezeBlockRegistry();
    _freezeOutletRegistry();
    _freezeConditionTypeRegistry();
  },
};
