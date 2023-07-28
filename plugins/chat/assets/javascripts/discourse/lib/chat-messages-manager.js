import { cached, tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/application";

export default class ChatMessagesManager {
  @tracked messages = [];

  constructor(owner) {
    setOwner(this, owner);
  }

  @cached
  get stagedMessages() {
    return this.messages.filterBy("staged");
  }

  @cached
  get selectedMessages() {
    return this.messages.filterBy("selected");
  }

  clearSelectedMessages() {
    this.selectedMessages.forEach((message) => (message.selected = false));
  }

  clear() {
    this.messages = [];
  }

  addMessages(messages = []) {
    this.messages = this.messages
      .concat(messages)
      .uniqBy("id")
      .sort((a, b) => a.createdAt - b.createdAt);
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
