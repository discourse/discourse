import NotificationTypeBase from "discourse/lib/notification-types/base";
import { setLastEditNotificationClick } from "discourse/models/post-stream";

export default class extends NotificationTypeBase {
  onClick() {
    setLastEditNotificationClick(
      this.notification.topic_id,
      this.notification.post_number,
      this.notification.data.revision_number
    );
  }
}
