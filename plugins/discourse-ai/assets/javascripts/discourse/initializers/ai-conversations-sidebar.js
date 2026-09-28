import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import AiBotSidebarNewConversation from "../components/ai-bot-sidebar-new-conversation";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager";

// Matches the rule the sidebar uses to treat a topic as an AI conversation
function isOwnBotConversation(routeInfo, currentUser) {
  for (let route = routeInfo; route; route = route.parent) {
    if (route.name === "topic") {
      const topic = route.attributes;
      return (
        topic?.archetype === "private_message" &&
        topic.user_id === currentUser?.id &&
        !!topic.is_bot_pm
      );
    }
  }

  return false;
}

export default {
  name: "ai-conversations-sidebar",

  initialize() {
    withPluginApi((api) => {
      const currentUser = api.container.lookup("service:current-user");
      const site = api.container.lookup("service:site");
      if (!currentUser && !site.ai_bot_anonymous_preview) {
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

            get mobileTab() {
              const hasBot = currentUser?.ai_enabled_chat_bots?.some(
                (bot) => !bot.is_agent || bot.has_default_llm
              );

              if (!hasBot) {
                return null;
              }

              return {
                label: i18n("discourse_ai.ai_bot.conversations.tab_label"),
                icon: "discobot",
                url: "/discourse-ai/ai-bot/conversations",
                ownsRoute: (routeInfo) =>
                  routeInfo.name === "discourse-ai-bot-conversations" ||
                  isOwnBotConversation(routeInfo, currentUser),
                isNestedRoute: (routeInfo) =>
                  routeInfo.name.startsWith("topic."),
              };
            }
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
          currentUser &&
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
