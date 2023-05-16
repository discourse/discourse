import User from "discourse/models/user";
import { tracked } from "@glimmer/tracking";

export default class ChatDirectMessage {
  static create(args = {}) {
    return new ChatDirectMessage(args);
  }

  @tracked id;
  @tracked users = null;

  constructor(args = {}) {
    this.id = args.chatable.id;
    this.users = this.#initUsers(args.chatable.users || []);
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
