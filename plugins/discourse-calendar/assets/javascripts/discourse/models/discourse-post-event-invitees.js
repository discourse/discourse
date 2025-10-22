import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import User from "discourse/models/user";
import DiscoursePostEventInvitee from "./discourse-post-event-invitee";

export default class DiscoursePostEventInvitees {
  static create(args = {}) {
    return new DiscoursePostEventInvitees(args);
  }

  @tracked _invitees;
  @tracked _suggestedUsers;

  constructor(args = {}) {
    this.invitees = args.invitees || [];
    this.suggestedUsers = args.meta?.suggested_users || [];
  }

  get invitees() {
    return this._invitees;
  }

  set invitees(invitees = []) {
    this._invitees = new TrackedArray(
      invitees.map((i) => DiscoursePostEventInvitee.create(i))
    );
  }

  get suggestedUsers() {
    return this._suggestedUsers;
  }

  set suggestedUsers(suggestedUsers = []) {
    this._suggestedUsers = new TrackedArray(
      suggestedUsers.map((su) => User.create(su))
    );
  }

  add(invitee) {
    this.invitees.push(invitee);

    this.suggestedUsers = this.suggestedUsers.filter(
      (su) => su.id !== invitee.user.id
    );
  }

  remove(invitee) {
    this.invitees = this.invitees.filter((i) => i.user.id !== invitee.user.id);
  }
}
