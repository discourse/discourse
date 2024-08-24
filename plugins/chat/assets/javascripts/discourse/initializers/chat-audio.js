import { withPluginApi } from "discourse/lib/plugin-api";

const MENTION = 29;
const MESSAGE = 30;
const CHAT_NOTIFICATION_TYPES = [MENTION, MESSAGE];

export default {
  name: "chat-audio",

  initialize(container) {
    const chat = container.lookup("service:chat");

    if (!chat.userCanChat) {
      return;
    }

    withPluginApi("0.12.1", (api) => {
      api.registerDesktopNotificationHandler((data, siteSettings, user) => {
        const indicatorType = user.user_option.chat_header_indicator_preference;
        const isMention = data.notification_type === MENTION;

        if (user.isInDoNotDisturb()) {
          return;
        }

        if (!user.chat_sound || indicatorType === "never") {
          return;
        }

        if (indicatorType === "only_mentions" && !isMention) {
          return;
        }

        if (
          indicatorType === "dm_and_mentions" &&
          !data.isDirectMessageChannel &&
          !isMention
        ) {
          return;
        }

        if (CHAT_NOTIFICATION_TYPES.includes(data.notification_type)) {
          const chatAudioManager = container.lookup(
            "service:chat-audio-manager"
          );
          chatAudioManager.play(user.chat_sound);
        }
      });
    });
  },
};
