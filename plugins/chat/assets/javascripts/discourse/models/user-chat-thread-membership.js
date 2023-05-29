import { tracked } from "@glimmer/tracking";

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
}
