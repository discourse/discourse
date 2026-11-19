import getURL from "discourse/lib/get-url";
import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class StaffReviewableNote extends NotificationTypeBase {
  get icon() {
    return "far-pen-to-square";
  }

  get description() {
    return i18n("notifications.staff_reviewable_note");
  }

  get linkHref() {
    return getURL(`/review/${this.notification.data.reviewable_id}`);
  }
}
