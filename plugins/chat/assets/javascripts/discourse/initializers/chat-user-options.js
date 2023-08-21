import { withPluginApi } from "discourse/lib/plugin-api";

const CHAT_ENABLED_FIELD = "chat_enabled";
const ONLY_CHAT_PUSH_NOTIFICATIONS_FIELD = "only_chat_push_notifications";
const IGNORE_CHANNEL_WIDE_MENTION = "ignore_channel_wide_mention";
const CHAT_SOUND = "chat_sound";
const CHAT_EMAIL_FREQUENCY = "chat_email_frequency";
const CHAT_HEADER_INDICATOR_PREFERENCE = "chat_header_indicator_preference";
const CHAT_SEPARATE_SIDEBAR_MODE = "chat_separate_sidebar_mode";

export default {
  name: "chat-user-options",

  initialize(container) {
    withPluginApi("0.11.0", (api) => {
      const siteSettings = container.lookup("service:site-settings");
      if (siteSettings.chat_enabled) {
        api.addSaveableUserOptionField(CHAT_ENABLED_FIELD);
        api.addSaveableUserOptionField(ONLY_CHAT_PUSH_NOTIFICATIONS_FIELD);
        api.addSaveableUserOptionField(IGNORE_CHANNEL_WIDE_MENTION);
        api.addSaveableUserOptionField(CHAT_SOUND);
        api.addSaveableUserOptionField(CHAT_EMAIL_FREQUENCY);
        api.addSaveableUserOptionField(CHAT_HEADER_INDICATOR_PREFERENCE);
        api.addSaveableUserOptionField(CHAT_SEPARATE_SIDEBAR_MODE);
      }
    });
  },
};
