import { PLUGIN_NAV_MODE_TOP } from "discourse/lib/admin-plugin-config-nav";
import { withPluginApi } from "discourse/lib/plugin-api";
import ChatAdminPluginActions from "discourse/plugins/chat/admin/components/chat-admin-plugin-actions";

export default {
  name: "discourse-chat-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi("1.1.0", (api) => {
      api.addAdminPluginConfigurationNav("chat", PLUGIN_NAV_MODE_TOP, [
        {
          label: "chat.incoming_webhooks.title",
          route: "adminPlugins.show.discourse-chat-incoming-webhooks",
        },
      ]);

      api.registerPluginHeaderActionComponent("chat", ChatAdminPluginActions);
    });
  },
};
