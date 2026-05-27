import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get linkHref() {
    // When the badge was granted for a specific post, link straight to
    // that post so the user can see what earned it. Otherwise fall back
    // to the badge page.
    const { topic_id, post_number } = this.notification.data;
    if (topic_id && post_number) {
      return getURL(`/t/${topic_id}/${post_number}`);
    }

    const badgeId = this.notification.data.badge_id;
    if (badgeId) {
      let slug = this.notification.data.badge_slug;
      if (!slug) {
        slug = this.notification.data.badge_name
          .replace(/[^A-Za-z0-9_]+/g, "-")
          .toLowerCase();
      }
      let username = this.notification.data.username;
      username = username ? `?username=${username.toLowerCase()}` : "";
      return getURL(`/badges/${badgeId}/${slug}${username}`);
    } else {
      return super.url;
    }
  }

  get description() {
    const topicTitle = this.notification.data.topic_title;
    if (topicTitle) {
      return i18n("notifications.granted_badge_for_post", {
        description: this.notification.data.badge_name,
        topic: topicTitle,
      });
    }

    return i18n("notifications.granted_badge", {
      description: this.notification.data.badge_name,
    });
  }

  get label() {
    return null;
  }
}
