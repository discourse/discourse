import { trustHTML } from "@ember/template";
import { withPluginApi } from "discourse/lib/plugin-api";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression, formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import BoostActionButton from "../components/boost-action-button";
import BoostsPostMenu from "../components/boosts-post-menu";

function initializeBoosts(api) {
  api.registerAppreciationNotificationType("boost");

  api.addSaveableUserOption("boost_notifications_level", {
    page: "notifications",
  });

  api.addTrackedPostProperties("boosts", "can_boost");

  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { buttonKeys } }) => {
      dag.add("discourse-boosts-action", BoostActionButton, {
        before: [buttonKeys.FLAG, buttonKeys.SHOW_MORE],
      });
    }
  );

  api.renderInOutlet("post-menu__after", BoostsPostMenu);

  api.registerCustomPostMessageCallback(
    "boost_added",
    (topicController, data) => {
      const postStream = topicController.get("model.postStream");
      const post = postStream.findLoadedPost(data.id);
      if (post) {
        const currentBoosts = post.boosts || [];
        const userId = data.boost.user?.id;
        const currentUser = topicController.currentUser;
        const existing = currentBoosts.some(
          (b) => b.id === data.boost.id || b.user?.id === userId
        );
        if (existing) {
          post.set(
            "boosts",
            currentBoosts.map((b) =>
              b.user?.id === userId ? { ...b, ...data.boost } : b
            )
          );
        } else {
          post.set("boosts", [...currentBoosts, data.boost]);
        }
        if (userId === currentUser?.id) {
          post.set("can_boost", false);
        }
      }
    }
  );

  api.registerCustomPostMessageCallback(
    "boost_removed",
    (topicController, data) => {
      const postStream = topicController.get("model.postStream");
      const post = postStream.findLoadedPost(data.id);
      if (post) {
        const removedBoost = (post.boosts || []).find(
          (b) => b.id === data.boost_id
        );
        post.set(
          "boosts",
          (post.boosts || []).filter((b) => b.id !== data.boost_id)
        );
        const currentUser = topicController.currentUser;
        if (removedBoost?.user?.id === currentUser?.id) {
          post.set("can_boost", true);
        }
      }
    }
  );

  api.registerNotificationTypeRenderer("boost", (NotificationTypeBase) => {
    return class extends NotificationTypeBase {
      get icon() {
        return "rocket";
      }

      get label() {
        const data = this.notification.data;
        const count = data.count;
        const uniqueUsernames = data.unique_usernames || [];
        const uniqueCount = uniqueUsernames.length;

        if (!count || count === 1 || !data.username2 || uniqueCount <= 1) {
          return this.username;
        }

        if (uniqueCount > 2) {
          return i18n("discourse_boosts.notification_multiple_users", {
            username: this.username,
            count: uniqueCount - 1,
          });
        }

        return i18n("discourse_boosts.notification_2_users", {
          username: this.username,
          username2: formatUsername(data.username2),
        });
      }

      get labelClasses() {
        const data = this.notification.data;
        if (data.username2) {
          return [data.count > 2 ? "multi-user" : "double-user"];
        }
      }

      get description() {
        const data = this.notification.data;

        if (data.count > 1) {
          return i18n("discourse_boosts.notification");
        }

        const raw = data.boost_raw;
        if (raw) {
          return trustHTML(emojiUnescape(escapeExpression(raw)));
        }

        return super.description;
      }
    };
  });
}

export default {
  name: "discourse-boosts",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_boosts_enabled) {
      withPluginApi(initializeBoosts);
    }
  },
};
