import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-data-explorer";

export default {
  name: "data-explorer-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "chart-line");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "explorer.title",
          route: "adminPlugins.show.explorer",
        },
      ]);
    });
  },
};
