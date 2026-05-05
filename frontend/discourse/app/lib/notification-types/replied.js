import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
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
    // Consolidated bucket notifications target the bucket parent's level
    // (not a single new post) so the user sees all the new content at
    // once. sort=new puts the latest first; collapse_replies hides
    // grandchildren so the catch-up view is uncluttered.
    if (this.isBucketed && this.consolidatedCount > 1 && this.topicId) {
      let url = getURL(`/n/${this.notification.slug}/${this.topicId}`);
      if (!this.isTopicBucket) {
        url += `/${this.notification.data.reply_to_post_number}`;
      }
      return `${url}?sort=new&collapse_replies=true`;
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
