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
    this.messages.clear();

    this.canLoadMoreFuture = null;
    this.canLoadMorePast = null;
  }

  addMessages(messages = []) {
    this.messages = this.messages
      .concat(messages)
      .uniqBy("id")
      .sortBy("createdAt");
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
      (message) => message.staged && message.id === stagedMessageId
    );
  }
}
