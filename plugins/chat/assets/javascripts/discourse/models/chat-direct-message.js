import User from "discourse/models/user";
import { tracked } from "@glimmer/tracking";

export default class ChatDirectMessage {
  static create(args = {}) {
    return new ChatDirectMessage(args);
  }

  @tracked users;

  constructor(args = {}) {
    this.users = this.#initUsers(args.users);
  }

  #initUsers(users = []) {
    return users.map((userData) => User.create(userData));
  }
}
