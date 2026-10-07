import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "voice-notifications",

  initialize() {
    withPluginApi((api) => {
      api.registerNotificationTypeRenderer(
        "voice_invitation",
        (NotificationTypeBase) => {
          return class extends NotificationTypeBase {
            // An invitation into an ephemeral room is a call.
            get isCall() {
              return !!this.notification.data.call;
            }

            get linkTitle() {
              return i18n(
                this.isCall
                  ? "notifications.titles.voice_call"
                  : "notifications.titles.voice_invitation"
              );
            }

            get icon() {
              return this.isCall ? "phone" : "microphone-lines";
            }

            get linkHref() {
              const data = this.notification.data;
              // Carries the inviter so joining from the notification credits
              // them, the same as a shared invite link.
              return getURL(
                `/voice/r/${data.room_slug}/invited-by/${encodeURIComponent(
                  data.display_username.toLowerCase()
                )}`
              );
            }

            get description() {
              if (this.isCall) {
                return i18n("notifications.voice_call");
              }

              return i18n("notifications.voice_invitation", {
                room_name: this.notification.data.room_name,
              });
            }
          };
        }
      );
    });
  },
};
