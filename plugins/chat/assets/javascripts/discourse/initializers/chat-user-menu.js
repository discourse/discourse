import getURL from "discourse/lib/get-url";
import { withPluginApi } from "discourse/lib/plugin-api";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";

export default {
  name: "chat-user-menu",
  initialize(container) {
    withPluginApi("1.3.0", (api) => {
      const chat = container.lookup("service:chat");

      if (!chat.userCanChat) {
        return;
      }

      if (api.registerNotificationTypeRenderer) {
        api.registerNotificationTypeRenderer(
          "chat_invitation",
          (NotificationItemBase) => {
            return class extends NotificationItemBase {
              linkTitle = i18n("notifications.titles.chat_invitation");
              icon = "link";
              description = i18n("notifications.chat_invitation");

              get linkHref() {
                const data = this.notification.data;
                const slug = slugifyChannel({
                  title: data.chat_channel_title,
                  slug: data.chat_channel_slug,
                });

                let url = `/chat/c/${slug || "-"}/${data.chat_channel_id}`;

                if (data.chat_message_id) {
                  url += `/${data.chat_message_id}`;
                }

                return getURL(url);
              }

              get label() {
                return formatUsername(
                  this.notification.data.invited_by_username
                );
              }
            };
          }
        );

        api.registerNotificationTypeRenderer(
          "chat_mention",
          (NotificationItemBase) => {
            return class extends NotificationItemBase {
              get linkHref() {
                const slug = slugifyChannel({
                  title: this.notification.data.chat_channel_title,
                  slug: this.notification.data.chat_channel_slug,
                });

                let notificationRoute = `/chat/c/${slug || "-"}/${
                  this.notification.data.chat_channel_id
                }`;
                if (this.notification.data.chat_thread_id) {
                  notificationRoute += `/t/${this.notification.data.chat_thread_id}`;
                } else {
                  notificationRoute += `/${this.notification.data.chat_message_id}`;
                }
                return getURL(notificationRoute);
              }

              get linkTitle() {
                return i18n("notifications.titles.chat_mention");
              }

              get icon() {
                return "d-chat";
              }

              get label() {
                return formatUsername(
                  this.notification.data.mentioned_by_username
                );
              }

              get description() {
                const identifier = this.notification.data.identifier
                  ? `@${this.notification.data.identifier}`
                  : null;

                const i18nPrefix = this.notification.data
                  .is_direct_message_channel
                  ? "notifications.popup.direct_message_chat_mention"
                  : "notifications.popup.chat_mention";

                const i18nSuffix = identifier ? "other_plain" : "direct";

                return i18n(`${i18nPrefix}.${i18nSuffix}`, {
                  identifier,
                  channel: this.notification.data.chat_channel_title,
                });
              }
            };
          }
        );

        api.registerNotificationTypeRenderer(
          "chat_watched_thread",
          (NotificationItemBase) => {
            return class extends NotificationItemBase {
              icon = "discourse-threads";
              linkTitle = i18n("notifications.titles.chat_watched_thread");
              description = this.notification.data.description;

              get label() {
                const data = this.notification.data;

                if (data.user_ids.length > 2) {
                  return i18n("notifications.chat_watched_thread_label", {
                    username: formatUsername(data.username2),
                    count: data.user_ids.length - 1,
                  });
                } else if (data.user_ids.length === 2) {
                  return i18n("notifications.chat_watched_thread_label", {
                    username: formatUsername(data.username2),
                    username2: formatUsername(data.username),
                    count: 1,
                  });
                } else {
                  return formatUsername(data.username);
                }
              }

              get linkHref() {
                const data = this.notification.data;
                return getURL(
                  `/chat/c/-/${data.chat_channel_id}/t/${data.chat_thread_id}/${data.chat_message_id}`
                );
              }
            };
          }
        );
      }

      if (api.registerUserMenuTab) {
        api.registerUserMenuTab((UserMenuTab) => {
          return class extends UserMenuTab {
            get id() {
              return "chat-notifications";
            }

            get panelComponent() {
              return "user-menu/chat-notifications-list";
            }

            get icon() {
              return "d-chat";
            }

            get count() {
              return (
                this.getUnreadCountForType("chat_mention") +
                this.getUnreadCountForType("chat_invitation") +
                this.getUnreadCountForType("chat_watched_thread")
              );
            }

            get notificationTypes() {
              return [
                "chat_invitation",
                "chat_mention",
                "chat_message",
                "chat_quoted",
                "chat_watched_thread",
              ];
            }
          };
        });
      }
    });
  },
};
