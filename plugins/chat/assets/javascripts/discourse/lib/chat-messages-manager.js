import { cached, tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/application";
import TrackedLinkedList from "ember-virtual-scroll-list/lib/tracked-linked-list";

export default class ChatMessagesManager {
  @tracked messages = new TrackedLinkedList();

  constructor(owner) {
    setOwner(this, owner);
  }

  @cached
  get stagedMessages() {
    return this.messages.filter((node) => node.value.staged);
  }

  @cached
  get selectedMessages() {
    return this.messages.filter((node) => node.value.selected);
  }

  clearSelectedMessages() {
    this.selectedMessages.forEach((node) => (node.value.selected = false));
  }

  clear() {
    this.messages = new TrackedLinkedList();
  }

  isFirstMessage(message) {
    return this.messages.first?.value?.id === message.id;
  }

  addMessages(messages = []) {
    messages.forEach((message) => {
      this.messages.insert(message);
    });
  }

  findMessage(messageId) {
    return this.messages.get(parseInt(messageId, 10))?.value;
  }

  findFirstMessageOfDay(aDate) {
    return this.messages.find(
      (node) =>
        aDate.getFullYear() === node.value.createdAt.getFullYear() &&
        aDate.getMonth() === node.value.createdAt.getMonth() &&
        aDate.getDate() === node.value.createdAt.getDate()
    )?.value;
  }

  removeMessage(message) {
    return this.messages.delete(message);
  }

  findStagedMessage(stagedMessageId) {
    return this.stagedMessages.find((node) => node.value.id === stagedMessageId)
      ?.value;
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
