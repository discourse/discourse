import { tracked } from "@glimmer/tracking";
import User from "discourse/models/user";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatDirectMessage {
  static create(args = {}) {
    return new ChatDirectMessage(args);
  }

  @tracked users;
  @tracked group;

  type = CHATABLE_TYPES.directMessageChannel;

  constructor(args = {}) {
    this.group = args.group ?? false;
    this.users = this.#initUsers(args.users || []);
  }

  #initUsers(users) {
    return users.map((user) => {
      if (!user || user instanceof User) {
        return user;
      } else {
        return User.create(user);
      }
    });
  }
}
