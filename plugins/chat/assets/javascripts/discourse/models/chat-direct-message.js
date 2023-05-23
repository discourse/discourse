import User from "discourse/models/user";
import { tracked } from "@glimmer/tracking";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatDirectMessage {
  static create(args = {}) {
    return new ChatDirectMessage(args);
  }

  @tracked id;
  @tracked users = null;

  type = CHATABLE_TYPES.directMessageChannel;

  constructor(args = {}) {
    this.id = args.id;
    this.users = this.#initUsers(args.users || []);
  }

  #initUsers(users) {
    return users.map((user) => {
      if (!user || user instanceof User) {
        return user;
      }

      return User.create(user);
    });
  }
}
