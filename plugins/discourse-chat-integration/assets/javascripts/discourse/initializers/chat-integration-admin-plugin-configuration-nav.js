import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-chat-integration";

export default {
  name: "chat-integration-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "plug");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "chat_integration.nav.providers",
          route: "adminPlugins.show.discourse-chat-integration-providers",
          description: "chat_integration.nav.providers_description",
        },
      ]);
    });
  },
};
