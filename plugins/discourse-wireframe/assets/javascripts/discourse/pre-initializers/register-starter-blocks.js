// @ts-check
import { withPluginApi } from "discourse/lib/plugin-api";
import WFCtaActions from "../blocks/wf-cta-actions";
import WFCtaCard from "../blocks/wf-cta-card";

/**
 * Registers the plugin's own blocks. The starter library that used to
 * live here now ships in core as builtin blocks, including the empty grid
 * cell (`layout-merged-cell`). What remains plugin-side is the composite
 * demo blocks `wf:cta-card` / `wf:cta-actions`, which showcase the core
 * `parts` composition capability (a block composed of other blocks, with
 * per-part overrides and full-depth nesting).
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
      api.registerBlock(WFCtaActions);
      api.registerBlock(WFCtaCard);
    });
  },
};
