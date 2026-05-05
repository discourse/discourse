import NotificationTypeBase from "discourse/lib/notification-types/base";
import { postUrl } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  get isBucketed() {
    return this.notification.data.reply_to_post_number != null;
  }

  get isTopicBucket() {
    return this.notification.data.reply_to_post_number === 1;
  }

  get consolidatedCount() {
    return this.notification.data.consolidated_count;
  }

  get linkHref() {
    if (this.isTopicBucket && this.topicId) {
      const url = postUrl(
        this.notification.slug,
        this.topicId,
        this.notification.post_number
      );
      return `${url}?sort=new`;
    }
    return super.linkHref;
  }

  get label() {
    if (this.consolidatedCount > 1 && this.isBucketed) {
      const key = this.isTopicBucket
        ? "notifications.replied_consolidated_in_topic"
        : "notifications.replied_consolidated_to_post";
      return i18n(key, { count: this.consolidatedCount });
    }
    return super.label;
  }
}
