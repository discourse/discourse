import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-oauth2-basic";

export default {
  name: "oauth2-basic-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "key");
    });
  },
};
