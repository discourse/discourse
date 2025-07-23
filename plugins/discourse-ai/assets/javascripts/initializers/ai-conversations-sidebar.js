import { withPluginApi } from "discourse/lib/plugin-api";
import AiBotSidebarNewConversation from "../discourse/components/ai-bot-sidebar-new-conversation";
import { AI_CONVERSATIONS_PANEL } from "../discourse/services/ai-conversations-sidebar-manager";

export default {
  name: "ai-conversations-sidebar",

  initialize() {
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      if (!siteSettings.ai_bot_enable_dedicated_ux) {
        return;
      }

      const currentUser = api.container.lookup("service:current-user");
      if (!currentUser) {
        return;
      }

      const aiConversationsSidebarManager = api.container.lookup(
        "service:ai-conversations-sidebar-manager"
      );
      aiConversationsSidebarManager.api = api;

      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class AiConversationsSidebarPanel extends BaseCustomSidebarPanel {
            key = AI_CONVERSATIONS_PANEL;
            hidden = true;
            displayHeader = false; // this would add a misplaced back to forum button
            expandActiveSection = true;
          }
      );

      api.renderInOutlet(
        "before-sidebar-sections",
        AiBotSidebarNewConversation
      );

      const setSidebarPanel = (transition) => {
        if (transition?.to?.name === "discourse-ai-bot-conversations") {
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        const topic = api.container.lookup("controller:topic").model;
        // if the topic is not a private message, not created by the current user,
        // or doesn't have a bot response, we don't need to override sidebar
        if (
          topic?.archetype === "private_message" &&
          topic.user_id === currentUser.id &&
          topic.is_bot_pm
        ) {
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        aiConversationsSidebarManager.stopForcingCustomSidebar();
      };

      api.container
        .lookup("service:router")
        .on("routeDidChange", setSidebarPanel);
    });
  },
};
