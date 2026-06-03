// @ts-check
import { withPluginApi } from "discourse/lib/plugin-api";
import WFCell from "../blocks/wf-cell";

/**
 * Registers the plugin's own blocks. The starter library that used to
 * live here now ships in core as builtin blocks; the only block that
 * remains plugin-side is `wf:cell`, an empty grid cell that is purely
 * an editing affordance (it renders nothing on the live page).
 *
 * Pre-initializer rather than api-initializer because the blocks registry
 * is frozen by the `freeze-block-registry` initializer; any
 * `api.registerBlock(...)` call after that point throws. Pre-initializers
 * run before initializers, so registration lands while the registry is
 * still mutable.
 */
export default {
  name: "discourse-wireframe:register-starter-blocks",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(WFCell);
    });
  },
};
