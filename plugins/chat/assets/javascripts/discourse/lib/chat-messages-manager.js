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
    return this.messages.filter((node) => node.value.staged).mapBy("value");
  }

  @cached
  get selectedMessages() {
    return this.messages.filter((node) => node.value.selected).mapBy("value");
  }

  clearSelectedMessages() {
    this.selectedMessages.forEach((messages) => (messages.selected = false));
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

  findFirstNonStaged() {
    return this.messages.find((node) => !node.value.staged)?.value;
  }

  findLastNonStaged() {
    return this.messages.findLast((node) => !node.value.staged)?.value;
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
    return this.stagedMessages.find(
      (message) => message.id === stagedMessageId
    );
  }

  findIndexOfMessage(id) {
    return this.messages.findIndex(id);
  }

  findLastMessage() {
    return this.messages.findLast((node) => !node.value.deletedAt)?.value;
  }

  get lastMessage() {
    return this.messages.last?.value;
  }

  findLastUserMessage(user) {
    return this.messages.findLast(
      (node) => node.value.user.id === user.id && !node.value.deletedAt
    )?.value;
  }
}
