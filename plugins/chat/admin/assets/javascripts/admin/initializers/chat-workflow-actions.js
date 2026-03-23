import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "chat-workflow-actions",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.chat_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer("workflow-node-icons", ({ value }) => {
        return {
          ...value,
          "action:send_chat_message": {
            name: "comment",
            icon: "comment",
            color: "var(--tertiary)",
          },
        };
      });
    });
  },
};
