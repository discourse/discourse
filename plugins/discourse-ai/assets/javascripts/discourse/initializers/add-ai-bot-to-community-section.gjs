import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "add-ai-bot-to-commmunity-section",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    const showSidebarLink = () => {
      return siteSettings.ai_bot_add_to_community_section;
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
