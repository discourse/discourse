import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "add-ai-bot-to-community-section",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");

    if (
      !currentUser ||
      !siteSettings.ai_bot_add_to_community_section ||
      !currentUser.ai_enabled_agents?.length
    ) {
      return;
    }

    const hasSelectableModel = currentUser.ai_available_llm_models?.length;
    const availableBots = currentUser.ai_enabled_agents.filter(
      (agent) =>
        agent.allow_personal_messages &&
        (agent.has_default_llm || hasSelectableModel)
    );

    if (availableBots.length === 0) {
      return;
    }

    withPluginApi((api) => {
      api.addCommunitySectionLink((baseSectionLink) => {
        return class AiBotSectionLink extends baseSectionLink {
          name = "ai-bot";
          route = "discourse-ai-bot-conversations";
          text = i18n("discourse_ai.ai_bot.shortcut_link");
          title = i18n("discourse_ai.ai_bot.shortcut_title");
          defaultPrefixValue = "discobot";
        };
      });
    });
  },
};
