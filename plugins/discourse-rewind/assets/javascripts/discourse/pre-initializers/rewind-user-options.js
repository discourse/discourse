import { withPluginApi } from "discourse/lib/plugin-api";

const ENABLED_FIELD_NAME = "discourse_rewind_enabled";
const SHARE_FIELD_NAME = "discourse_rewind_share_publicly";

export default {
  name: "rewind-user-options",

  initialize(container) {
    withPluginApi((api) => {
      const siteSettings = container.lookup("service:site-settings");
      if (siteSettings.discourse_rewind_enabled) {
        api.addSaveableUserOptionField(ENABLED_FIELD_NAME);
        api.addSaveableUserOptionField(SHARE_FIELD_NAME);
      }
    });
  },
};
