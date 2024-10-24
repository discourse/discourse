import { withPluginApi } from "discourse/lib/plugin-api";
import { capabilities } from "discourse/services/capabilities";
import { INDICATOR_PREFERENCES } from "discourse/plugins/chat/discourse/lib/chat-constants";

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

    this.supportsServiceWorker = () => {
      if (
        !(
          "serviceWorker" in navigator &&
          typeof ServiceWorkerRegistration !== "undefined" &&
          !capabilities.isAppWebview &&
          navigator.serviceWorker.controller &&
          navigator.serviceWorker.controller.state === "activated"
        )
      ) {
        return false;
      }

      return true;
    };

    this.canPlaySound = () => {
      return new Promise((resolve) => {
        if (this.supportsServiceWorker()) {
          navigator.serviceWorker.addEventListener("message", (event) => {
            if ("canPlaySound" in event.data) {
              resolve(event.data.canPlaySound);
            } else {
              resolve(false);
            }
          });

          navigator.serviceWorker.ready.then((registration) => {
            registration.active.postMessage({ chatSound: true });
          });
        } else {
          resolve(true);
        }
      });
    };

    withPluginApi("0.12.1", (api) => {
      api.registerDesktopNotificationHandler((data, siteSettings, user) => {
        const indicatorType = user.user_option.chat_header_indicator_preference;
        const isMention = data.notification_type === MENTION;

        if (user.isInDoNotDisturb()) {
          return;
        }

        if (!user.chat_sound || indicatorType === INDICATOR_PREFERENCES.never) {
          return;
        }

        if (
          indicatorType === INDICATOR_PREFERENCES.only_mentions &&
          !isMention
        ) {
          return;
        }

        if (
          indicatorType === INDICATOR_PREFERENCES.dm_and_mentions &&
          !data.is_direct_message_channel &&
          !isMention
        ) {
          return;
        }

        if (CHAT_NOTIFICATION_TYPES.includes(data.notification_type)) {
          this.canPlaySound().then((success) => {
            if (!success) {
              return;
            }
            const chatAudioManager = container.lookup(
              "service:chat-audio-manager"
            );
            chatAudioManager.play(user.chat_sound);
          });
        }
      });
    });
  },
};
