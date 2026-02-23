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
  @tracked lastViewedPinsAt;
  @tracked starred;
  @tracked hasUnseenPins;
  @tracked user;

  constructor(args = {}) {
    this.following = args.following;
    this.muted = args.muted;
    this.notificationLevel = args.notification_level;
    this.lastReadMessageId = args.last_read_message_id;
    this.lastViewedAt = new Date(args.last_viewed_at);
    this.lastViewedPinsAt = args.last_viewed_pins_at
      ? new Date(args.last_viewed_pins_at)
      : null;
    this.starred = args.starred;
    this.hasUnseenPins = args.has_unseen_pins;
    this.user = this.#initUserModel(args.user);
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }
}
