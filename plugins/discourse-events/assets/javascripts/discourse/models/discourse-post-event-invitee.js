import { tracked } from "@glimmer/tracking";
import User from "discourse/models/user";

export default class DiscoursePostEventInvitee {
  static create(args = {}) {
    return new DiscoursePostEventInvitee(args);
  }

  @tracked status;
  @tracked recurring;

  constructor(args = {}) {
    this.id = args.id;
    this.post_id = args.post_id;
    this.status = args.status;
    this.recurring = args.recurring;
    this.user = this.#initUserModel(args.user);
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }
}
