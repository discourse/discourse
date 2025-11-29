import { cached } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { trackedArray } from "discourse/lib/tracked-tools";

export default class ChatMessagesManager {
  @trackedArray messages = [];

  constructor(owner) {
    setOwner(this, owner);
  }

  @cached
  get stagedMessages() {
    return this.messages.filter((message) => message.staged);
  }

  @cached
  get selectedMessages() {
    return this.messages.filter((message) => message.selected);
  }

  clearSelectedMessages() {
    this.selectedMessages.forEach((message) => (message.selected = false));
  }

  clear() {
    this.messages = [];
  }

  addMessages(messages = []) {
    this.messages = uniqueItemsFromArray(
      this.messages.concat(messages),
      "id"
    ).sort((a, b) => a.createdAt - b.createdAt);
  }

  findMessage(messageId) {
    return this.messages.find(
      (message) => message.id === parseInt(messageId, 10)
    );
  }

  findFirstMessageOfDay(a) {
    return this.messages.find(
      (b) =>
        a.getFullYear() === b.createdAt.getFullYear() &&
        a.getMonth() === b.createdAt.getMonth() &&
        a.getDate() === b.createdAt.getDate()
    );
  }

  removeMessage(message) {
    return this.messages.removeObject(message);
  }

  findStagedMessage(stagedMessageId) {
    return this.stagedMessages.find(
      (message) => message.id === stagedMessageId
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
