import { tracked } from "@glimmer/tracking";
import User from "discourse/models/user";

export default class UserChatChannelMembership {
  static create(args = {}) {
    return new UserChatChannelMembership(args);
  }

  @tracked following;
  @tracked muted;
  @tracked notificationLevel;
  @tracked lastReadMessageId;
  @tracked lastViewedAt;
  @tracked user;

  constructor(args = {}) {
    this.following = args.following;
    this.muted = args.muted;
    this.notificationLevel = args.notification_level;
    this.lastReadMessageId = args.last_read_message_id;
    this.lastViewedAt = new Date(args.last_viewed_at);
    this.user = this.#initUserModel(args.user);
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }
}
