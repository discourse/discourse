import { withPluginApi } from "discourse/lib/plugin-api";

const CHAT_ENABLED_FIELD = "chat_enabled";
const ONLY_CHAT_PUSH_NOTIFICATIONS_FIELD = "only_chat_push_notifications";
const IGNORE_CHANNEL_WIDE_MENTION = "ignore_channel_wide_mention";
const SHOW_THREAD_TITLE_PROMPTS = "show_thread_title_prompts";
const CHAT_SOUND = "chat_sound";
const CHAT_EMAIL_FREQUENCY = "chat_email_frequency";
const CHAT_HEADER_INDICATOR_PREFERENCE = "chat_header_indicator_preference";
const CHAT_SEPARATE_SIDEBAR_MODE = "chat_separate_sidebar_mode";
const CHAT_SEND_SHORTCUT = "chat_send_shortcut";
const CHAT_QUICK_REACTION_TYPE = "chat_quick_reaction_type";
const CHAT_QUICK_REACTIONS_CUSTOM = "chat_quick_reactions_custom";

export default {
  name: "chat-user-options",

  initialize(container) {
    withPluginApi("0.11.0", (api) => {
      const siteSettings = container.lookup("service:site-settings");
      if (siteSettings.chat_enabled) {
        api.addSaveableUserOptionField(CHAT_ENABLED_FIELD);
        api.addSaveableUserOptionField(ONLY_CHAT_PUSH_NOTIFICATIONS_FIELD);
        api.addSaveableUserOptionField(IGNORE_CHANNEL_WIDE_MENTION);
        api.addSaveableUserOptionField(SHOW_THREAD_TITLE_PROMPTS);
        api.addSaveableUserOptionField(CHAT_SOUND);
        api.addSaveableUserOptionField(CHAT_EMAIL_FREQUENCY);
        api.addSaveableUserOptionField(CHAT_HEADER_INDICATOR_PREFERENCE);
        api.addSaveableUserOptionField(CHAT_SEPARATE_SIDEBAR_MODE);
        api.addSaveableUserOptionField(CHAT_SEND_SHORTCUT);
        api.addSaveableUserOptionField(CHAT_QUICK_REACTION_TYPE);
        api.addSaveableUserOptionField(CHAT_QUICK_REACTIONS_CUSTOM);
      }
    });
  },
};
