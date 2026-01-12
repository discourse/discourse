import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-templates";

export default {
  name: "templates-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "far-clipboard");
    });
  },
};
