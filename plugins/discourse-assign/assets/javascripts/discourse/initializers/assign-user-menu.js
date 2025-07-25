import { htmlSafe } from "@ember/template";
import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUnescape } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import UserMenuAssignNotificationsList from "../components/user-menu/assigns-list";

export default {
  name: "assign-user-menu",

  initialize(container) {
    withPluginApi("1.2.0", (api) => {
      const siteSettings = container.lookup("service:site-settings");
      if (!siteSettings.assign_enabled) {
        return;
      }

      const currentUser = api.getCurrentUser();
      if (!currentUser?.can_assign) {
        return;
      }

      if (api.registerNotificationTypeRenderer) {
        api.registerNotificationTypeRenderer(
          "assigned",
          (NotificationItemBase) => {
            return class extends NotificationItemBase {
              get linkTitle() {
                if (this.isGroup()) {
                  return i18n(`user.assigned_to_group.${this.postOrTopic()}`, {
                    group_name: this.notification.data.display_username,
                  });
                }
                return i18n(`user.assigned_to_you.${this.postOrTopic()}`);
              }

              get icon() {
                return this.isGroup() ? "group-plus" : "user-plus";
              }

              get label() {
                if (!this.isGroup()) {
                  return "";
                }
                return this.notification.data.display_username;
              }

              get description() {
                return htmlSafe(
                  emojiUnescape(
                    i18n(`user.assignment_description.${this.postOrTopic()}`, {
                      topic_title: this.notification.fancy_title,
                      post_number: this.notification.post_number,
                    })
                  )
                );
              }

              isGroup() {
                return (
                  this.notification.data.message ===
                  "discourse_assign.assign_group_notification"
                );
              }

              postOrTopic() {
                return this.notification.post_number === 1 ? "topic" : "post";
              }
            };
          }
        );
      }

      if (api.registerUserMenuTab) {
        api.registerUserMenuTab((UserMenuTab) => {
          return class extends UserMenuTab {
            id = "assign-list";
            panelComponent = UserMenuAssignNotificationsList;
            icon = "user-plus";
            notificationTypes = ["assigned"];

            get count() {
              return this.getUnreadCountForType("assigned");
            }

            get linkWhenActive() {
              return `${this.currentUser.path}/activity/assigned`;
            }
          };
        });
      }
    });
  },
};
