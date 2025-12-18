import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "automation";

export default {
  name: "automation-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "wand-magic-sparkles");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "discourse_automation.title",
          route: "adminPlugins.show.automation",
        },
      ]);
    });
  },
};
