import type { BlockClass } from "discourse/lib/blocks/-internals/types";
import { type PluginApi, withPluginApi } from "discourse/lib/plugin-api";
import WFCtaActions from "../blocks/wf-cta-actions";
import WFCtaCard from "../blocks/wf-cta-card";

// TODO(devxp-typescript-pending): use `PluginApi` directly once core declares
// the `registerBlock` parameter on its JavaScript-backed public type.
type BlockRegistrationPluginApi = Omit<PluginApi, "registerBlock"> & {
  /** Registers a block component before the registry is frozen. */
  registerBlock(
    /** Decorated block component to register. */
    block: BlockClass
  ): void;
};

/**
 * Registers the plugin's composite demonstration blocks before the core block
 * registry is frozen.
 */
export default {
  name: "discourse-wireframe:register-starter-blocks",
  before: "freeze-block-registry",

  /** Registers the plugin-owned blocks with the core plugin API. */
  initialize(): void {
    withPluginApi((api: BlockRegistrationPluginApi): void => {
      api.registerBlock(WFCtaActions);
      api.registerBlock(WFCtaCard);
    });
  },
};
