import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class StaffQueuedPostReview extends NotificationTypeBase {
  get description() {
    return this.notification.data.outcome === "approved"
      ? i18n("notifications.staff_queued_post_approved")
      : i18n("notifications.staff_queued_post_rejected");
  }

  get linkHref() {
    return getURL(`/review/${this.notification.data.reviewable_id}`);
  }
}
