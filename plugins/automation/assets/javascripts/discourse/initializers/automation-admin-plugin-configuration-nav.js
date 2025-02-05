import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "automation-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi("1.1.0", (api) => {
      api.addAdminPluginConfigurationNav("automation", [
        {
          label: "discourse_automation.title",
          route: "adminPlugins.show.automation",
        },
      ]);
    });
  },
};
