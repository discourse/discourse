import { cached } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import {
  removeValueFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";
import { autoTrackedArray } from "discourse/lib/tracked-tools";

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
    ).sort((a, b) => a.createdAt - b.createdAt);
  }

  findMessage(messageId) {
    return this.messages.find(
      (message) => message.id === parseInt(messageId, 10)
    );
  }

  findFirstMessageOfDay(date, timezone) {
    const resolvedTimezone = timezone || moment.tz.guess();
    const targetDate = moment(date).tz(resolvedTimezone);

    return this.messages.find((message) =>
      targetDate.isSame(moment(message.createdAt).tz(resolvedTimezone), "day")
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
