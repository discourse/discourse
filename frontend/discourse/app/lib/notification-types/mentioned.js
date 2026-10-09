import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";

export default class Mentioned extends NotificationTypeBase {
  get description() {
    if (this.notification.data.reviewable_id) {
      return this.notification.data.topic_title;
    }

    return super.description;
  }

  get linkHref() {
    if (this.notification.data.reviewable_id) {
      return getURL(`/review/${this.notification.data.reviewable_id}`);
    }

    return super.linkHref;
  }
}
