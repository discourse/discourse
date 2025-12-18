import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "chat-user-options",

  initialize(container) {
    withPluginApi((api) => {
      const { chat_enabled } = container.lookup("service:site-settings");

      if (chat_enabled) {
        // Chat settings
        api.addSaveableUserOption("chat_enabled");
        api.addSaveableUserOption("chat_header_indicator_preference");
        api.addSaveableUserOption("chat_quick_reaction_type");
        api.addSaveableUserOption("chat_quick_reactions_custom");
        api.addSaveableUserOption("chat_send_shortcut");
        api.addSaveableUserOption("chat_separate_sidebar_mode");
        api.addSaveableUserOption("chat_sound");
        api.addSaveableUserOption("ignore_channel_wide_mention");
        api.addSaveableUserOption("only_chat_push_notifications");
        api.addSaveableUserOption("show_thread_title_prompts");
        // Email settings
        api.addSaveableUserOption("chat_email_frequency", { page: "emails" });
      }
    });
  },
};
