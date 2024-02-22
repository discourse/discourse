import { tracked } from "@glimmer/tracking";
import { NotificationLevels } from "discourse/lib/notification-levels";

export default class UserChatThreadMembership {
  static create(args = {}) {
    return new UserChatThreadMembership(args);
  }

  @tracked lastReadMessageId = null;
  @tracked notificationLevel = null;

  constructor(args = {}) {
    this.lastReadMessageId = args.last_read_message_id;
    this.notificationLevel = args.notification_level;
  }

  get isQuiet() {
    return (
      this.notificationLevel === NotificationLevels.REGULAR ||
      this.notificationLevel === NotificationLevels.MUTED
    );
  }
}
