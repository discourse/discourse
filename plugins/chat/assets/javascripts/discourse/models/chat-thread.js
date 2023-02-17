import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
import { escapeExpression } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";

export const THREAD_STATUSES = {
  open: "open",
  readOnly: "read_only",
  closed: "closed",
  archived: "archived",
};

export default class ChatThread extends RestModel {
  @tracked title;
  @tracked status;

  get escapedTitle() {
    return escapeExpression(this.title);
  }
}

ChatThread.reopenClass({
  create(args) {
    args = args || {};
    if (!args.original_message_user instanceof User) {
      args.original_message_user = User.create(args.original_message_user);
    }
    args.original_message.user = args.original_message_user;
    return this._super(args);
  },
});
