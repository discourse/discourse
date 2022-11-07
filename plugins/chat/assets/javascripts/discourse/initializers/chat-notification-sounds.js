import { withPluginApi } from "discourse/lib/plugin-api";
import discourseDebounce from "discourse-common/lib/debounce";

export const CHAT_SOUNDS = {
  bell: "/plugins/chat/audio/bell.mp3",
  ding: "/plugins/chat/audio/ding.mp3",
};

const MENTION = 29;
const MESSAGE = 30;
const CHAT_NOTIFICATION_TYPES = [MENTION, MESSAGE];

const AUDIO_DEBOUNCE_TIMEOUT = 3000;

export default {
  name: "chat-notification-sounds",
  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const chatService = container.lookup("service:chat");

    if (!chatService.userCanChat || !currentUser?.chat_sound) {
      return;
    }

    function playAudio(user) {
      const audio = new Audio(CHAT_SOUNDS[user.chat_sound]);
      audio.play().catch(() => {
        // eslint-disable-next-line no-console
        console.info(
          "User needs to interact with DOM before we can play notification sounds"
        );
      });
    }

    function playAudioWithDebounce(user) {
      discourseDebounce(this, playAudio, user, AUDIO_DEBOUNCE_TIMEOUT, true);
    }

    withPluginApi("0.12.1", (api) => {
      api.registerDesktopNotificationHandler((data, siteSettings, user) => {
        if (CHAT_NOTIFICATION_TYPES.includes(data.notification_type)) {
          playAudioWithDebounce(user);
        }
      });
    });
  },
};
