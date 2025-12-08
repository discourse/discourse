import { withPluginApi } from "discourse/lib/plugin-api";

const FIELD_NAME = "discourse_rewind_disabled";

export default {
  name: "rewind-user-options",

  initialize(container) {
    withPluginApi((api) => {
      const siteSettings = container.lookup("service:site-settings");
      if (siteSettings.discourse_rewind_enabled) {
        api.addSaveableUserOptionField(FIELD_NAME);
      }
    });
  },
};
