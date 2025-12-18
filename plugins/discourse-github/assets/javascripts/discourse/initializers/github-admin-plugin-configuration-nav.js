import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-github";

export default {
  name: "github-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "fab-github");
    });
  },
};
