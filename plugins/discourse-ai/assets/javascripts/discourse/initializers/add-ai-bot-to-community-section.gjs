import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "add-ai-bot-to-commmunity-section",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");

    const getAvailableBots = () => {
      const availableBots = currentUser.ai_enabled_chat_bots
        .filter((bot) => !bot.is_persona || bot.has_default_llm)
        .filter(Boolean);

      return availableBots ? availableBots.map((bot) => bot.model_name) : [];
    };

    const showSidebarLink = () => {
      return (
        getAvailableBots().length > 0 &&
        siteSettings.ai_bot_add_to_community_section
      );
    };

    if (showSidebarLink()) {
      withPluginApi((api) => {
        api.addCommunitySectionLink((baseSectionLink) => {
          return class AiBotSectionLink extends baseSectionLink {
            name = "ai-bot";
            route = "discourse-ai-bot-conversations";
            text = i18n("discourse_ai.ai_bot.shortcut_link");
            title = i18n("discourse_ai.ai_bot.shortcut_title");
            defaultPrefixValue = "robot";
          };
        });
      });
    }
  },
};
