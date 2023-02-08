import RestModel from "discourse/models/rest";
import I18n from "I18n";
import User from "discourse/models/user";
import { escapeExpression } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";

export const THREAD_STATUSES = {
  open: "open",
  readOnly: "read_only",
  closed: "closed",
  archived: "archived",
};

export function threadStatusName(status) {
  switch (status) {
    case THREAD_STATUSES.open:
      return I18n.t("chat.thread_status.open");
    case THREAD_STATUSES.readOnly:
      return I18n.t("chat.thread_status.read_only");
    case THREAD_STATUSES.closed:
      return I18n.t("chat.thread_status.closed");
    case THREAD_STATUSES.archived:
      return I18n.t("chat.thread_status.archived");
  }
}

const READONLY_STATUSES = [
  THREAD_STATUSES.closed,
  THREAD_STATUSES.readOnly,
  THREAD_STATUSES.archived,
];

const STAFF_READONLY_STATUSES = [
  THREAD_STATUSES.readOnly,
  THREAD_STATUSES.archived,
];

export default class ChatThread extends RestModel {
  @tracked title;
  @tracked status;

  get escapedTitle() {
    return escapeExpression(this.title);
  }

  get isOpen() {
    return this.status === THREAD_STATUSES.open;
  }

  get isReadOnly() {
    return this.status === THREAD_STATUSES.readOnly;
  }

  get isClosed() {
    return this.status === THREAD_STATUSES.closed;
  }

  get isArchived() {
    return this.status === THREAD_STATUSES.archived;
  }

  canModifyMessages(user) {
    if (user.staff) {
      return !STAFF_READONLY_STATUSES.includes(this.status);
    }

    return !READONLY_STATUSES.includes(this.status);
  }
}

ChatThread.reopenClass({
  create(args) {
    args = args || {};
    args.original_message_user = User.create(args.original_message_user);
    args.original_message.user = args.original_message_user;
    return this._super(args);
  },
});
