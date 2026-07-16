import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "chat-user-options",

  initialize(container) {
    withPluginApi((api) => {
      const { chat_enabled } = container.lookup("service:site-settings");

      if (chat_enabled) {
        // Chat settings
        api.addSaveableUserOption("chat_announce_new_messages");
        api.addSaveableUserOption("chat_new_message_sound");
        api.addSaveableUserOption("chat_enabled");
        api.addSaveableUserOption("chat_quick_reaction_type");
        api.addSaveableUserOption("chat_quick_reactions_custom");
        api.addSaveableUserOption("chat_send_shortcut");
        api.addSaveableUserOption("chat_separate_sidebar_mode");
        api.addSaveableUserOption("show_thread_title_prompts");
        // Notification settings (rendered on the notifications preferences tab)
        api.addSaveableUserOption("chat_header_indicator_preference", {
          page: "notifications",
        });
        api.addSaveableUserOption("chat_sound", { page: "notifications" });
        api.addSaveableUserOption("ignore_channel_wide_mention", {
          page: "notifications",
        });
        // Email settings
        api.addSaveableUserOption("chat_email_frequency", { page: "emails" });
      }
    });
  },
};
