import { _freezeBlockRegistry } from "discourse/lib/blocks/registration";

/**
 * Initializer that freezes the block registry.
 *
 * After this initializer runs:
 * - `api.registerBlock()` will throw an error (registry is frozen)
 * - `api.renderBlocks()` can use registered blocks
 *
 * Plugins and themes must register blocks in pre-initializers
 * that run before this initializer (using `before: "freeze-valid-blocks"`).
 *
 * @example
 * ```javascript
 * // In a pre-initializer (themes/my-theme/javascripts/discourse/pre-initializers/register-blocks.js)
 * export default {
 *   before: "freeze-valid-blocks",
 *   initialize() {
 *     withPluginApi("1.0", (api) => {
 *       api.registerBlock(MyBlock);
 *     });
 *   },
 * };
 * ```
 */
export default {
  before: "inject-discourse-objects",
  after: "discourse-bootstrap",

  initialize() {
    _freezeBlockRegistry();
  },
};
