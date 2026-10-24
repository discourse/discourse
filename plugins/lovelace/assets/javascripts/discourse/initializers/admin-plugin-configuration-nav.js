import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "lovelace-admin-plugin-configuration-nav",
  initialize(container) {
    if (!container.lookup("service:current-user")?.admin) {
      return;
    }
    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav("lovelace", [
        {
          label: "lovelace.onboarding.title",
          route: "adminPlugins.show.lovelace-onboarding",
          description: "lovelace.onboarding.description",
        },
        {
          label: "lovelace.configure",
          route: "adminPlugins.show.lovelace-checklist",
        },
      ]);
    });
  },
};
