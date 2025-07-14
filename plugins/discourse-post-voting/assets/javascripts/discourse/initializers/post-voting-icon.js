import { withPluginApi } from "discourse/lib/plugin-api";
import { postUrl } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { buildAnchorId } from "../components/post-voting-comment";

export default {
  name: "post-voting-icon",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.post_voting_enabled) {
      return;
    }

    withPluginApi("1.18.0", (api) => {
      api.registerNotificationTypeRenderer(
        "question_answer_user_commented",
        (NotificationTypeBase) => {
          return class extends NotificationTypeBase {
            get linkTitle() {
              return i18n(
                "notifications.titles.question_answer_user_commented"
              );
            }

            get linkHref() {
              const url = postUrl(
                this.notification.slug,
                this.topicId,
                this.notification.post_number
              );
              return `${url}#${buildAnchorId(
                this.notification.data.post_voting_comment_id
              )}`;
            }

            get icon() {
              return "comment";
            }
          };
        }
      );
    });
  },
};
