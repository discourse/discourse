import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "rewind-user-options",

  initialize(container) {
    withPluginApi((api) => {
      const { discourse_rewind_enabled } = container.lookup(
        "service:site-settings"
      );

      if (discourse_rewind_enabled) {
        api.addSaveableUserOption("discourse_rewind_enabled");
        api.addSaveableUserOption("discourse_rewind_share_publicly");
      }
    });
  },
};
