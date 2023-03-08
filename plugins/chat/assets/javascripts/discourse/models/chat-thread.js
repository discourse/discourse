import { TrackedArray } from "@ember-compat/tracked-built-ins";
import User from "discourse/models/user";
import { escapeExpression } from "discourse/lib/utilities";
import { tracked } from "@glimmer/tracking";

export const THREAD_STATUSES = {
  open: "open",
  readOnly: "read_only",
  closed: "closed",
  archived: "archived",
};

export default class ChatThread {
  @tracked title;
  @tracked status;
  @tracked messages = new TrackedArray();

  constructor(args = {}) {
    this.title = args.title;
    this.id = args.id;
    this.status = args.status;

    this.originalMessageUser = this.#initUserModel(args.original_message_user);
    // TODO (martin) Not sure if ChatMessage is needed here, original_message
    // only has a small subset of message stuff.
    // this.originalMessage = new ChatMessage(args.original_message);
    this.originalMessage = args.original_message;
    this.originalMessage.user = this.originalMessageUser;
  }

  get escapedTitle() {
    return escapeExpression(this.title);
  }

  clearMessages() {
    this.messages.clear();

    this.canLoadMoreFuture = null;
    this.canLoadMorePast = null;
  }

  appendMessages(messages) {
    this.messages.pushObjects(messages);
  }

  prependMessages(messages) {
    this.messages.unshiftObjects(messages);
  }

  findMessage(messageId) {
    return this.messages.find(
      (message) => message.id === parseInt(messageId, 10)
    );
  }

  removeMessage(message) {
    return this.messages.removeObject(message);
  }

  findStagedMessage(stagedMessageId) {
    return this.messages.find(
      (message) => message.stagedId === stagedMessageId
    );
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }
}
