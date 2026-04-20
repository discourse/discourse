import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "ai-conversations-sidebar",

  initialize() {
    withPluginApi((api) => {
      const currentUser = api.container.lookup("service:current-user");
      if (!currentUser) {
        return;
      }

      const setBodyClass = (transition) => {
        const inConversationsRoute =
          transition?.to?.name === "discourse-ai-bot-conversations";

        const topic = api.container.lookup("controller:topic").model;
        const inBotPm =
          topic?.archetype === "private_message" &&
          topic.user_id === currentUser.id &&
          topic.is_bot_pm;

        if (inConversationsRoute || inBotPm) {
          document.body.classList.add("has-ai-conversations-sidebar");
        } else {
          document.body.classList.remove("has-ai-conversations-sidebar");
          document.body.classList.remove("has-empty-ai-conversations-sidebar");
        }
      };

      api.container.lookup("service:router").on("routeDidChange", setBodyClass);
    });
  },
};
