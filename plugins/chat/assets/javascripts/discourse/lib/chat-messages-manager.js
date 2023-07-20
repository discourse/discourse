import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { setOwner } from "@ember/application";

export default class ChatMessagesManager {
  @tracked messages = new TrackedArray();
  @tracked canLoadMoreFuture;
  @tracked canLoadMorePast;

  constructor(owner) {
    setOwner(this, owner);
  }

  clearMessages() {
    this.messages.forEach((message) => (message.manager = null));
    this.messages.clear();

    this.canLoadMoreFuture = null;
    this.canLoadMorePast = null;
  }

  addMessages(messages = []) {
    messages.forEach((message) => {
      message.manager = this;
    });

    this.messages = new TrackedArray(
      this.messages.concat(messages).uniqBy("id").sortBy("createdAt")
    );
  }

  findMessage(messageId) {
    return this.messages.find(
      (message) => message.id === parseInt(messageId, 10)
    );
  }

  findFirstMessageOfDay(messageDate) {
    const targetDay = new Date(messageDate).toDateString();
    return this.messages.find(
      (message) => new Date(message.createdAt).toDateString() === targetDay
    );
  }

  removeMessage(message) {
    return this.messages.removeObject(message);
  }

  findStagedMessage(stagedMessageId) {
    return this.messages.find(
      (message) => message.staged && message.id === stagedMessageId
    );
  }

  findIndexOfMessage(id) {
    return this.messages.findIndex((m) => m.id === id);
  }

  findLastMessage() {
    return this.messages.findLast((message) => !message.deletedAt);
  }

  findLastUserMessage(user) {
    return this.messages.findLast(
      (message) => message.user.id === user.id && !message.deletedAt
    );
  }
}
