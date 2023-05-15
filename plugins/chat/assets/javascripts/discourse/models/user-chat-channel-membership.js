import { tracked } from "@glimmer/tracking";
import User from "discourse/models/user";

export default class UserChatChannelMembership {
  static create(args = {}) {
    return new UserChatChannelMembership(args);
  }

  @tracked following = false;
  @tracked muted = false;
  @tracked desktopNotificationLevel = null;
  @tracked mobileNotificationLevel = null;
  @tracked lastReadMessageId = null;
  @tracked user = null;

  constructor(args = {}) {
    this.following = args.following;
    this.muted = args.muted;
    this.desktopNotificationLevel = args.desktop_notification_level;
    this.mobileNotificationLevel = args.mobile_notification_level;
    this.lastReadMessageId = args.last_read_message_id;
    this.user = this.#initUserModel(args.user);
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }
}
