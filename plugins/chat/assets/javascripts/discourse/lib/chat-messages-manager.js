import { cached } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import {
  removeValueFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";
import { autoTrackedArray } from "discourse/lib/tracked-tools";

/**
 * Staged messages only carry the sender's clock, so they sort after every
 * confirmed message. Server timestamps arrive without milliseconds, so ids
 * break ties.
 */
function compareMessages(a, b) {
  if (a.staged !== b.staged) {
    return a.staged ? 1 : -1;
  }

  if (a.staged) {
    return 0;
  }

  return a.createdAt - b.createdAt || a.id - b.id;
}

export default class ChatMessagesManager {
  @autoTrackedArray messages = [];

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
    ).sort(compareMessages);
  }

  sortMessages() {
    this.messages = this.messages.toSorted(compareMessages);
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
    return removeValueFromArray(this.messages, message);
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
