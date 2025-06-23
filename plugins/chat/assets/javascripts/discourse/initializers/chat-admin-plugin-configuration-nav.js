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
      api.addAdminPluginConfigurationNav("chat", [
        {
          label: "chat.incoming_webhooks.title",
          route: "adminPlugins.show.discourse-chat-incoming-webhooks",
          description: "chat.incoming_webhooks.header_description",
        },
      ]);

      api.registerPluginHeaderActionComponent("chat", ChatAdminPluginActions);
    });
  },
};
