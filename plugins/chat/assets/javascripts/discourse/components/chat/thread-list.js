import Component from "@glimmer/component";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatThreadList extends Component {
  @service chat;
  @service messageBus;

  @tracked loading = true;

  // NOTE: This replicates sort logic from the server. We need this because
  // the thread unread count + last reply date + time update when new messages
  // are sent to the thread, and we want the list to react in realtime to this.
  get sortedThreads() {
    if (!this.args.channel.threadsManager.threads) {
      return [];
    }

    return this.args.channel.threadsManager.threads.sort((threadA, threadB) => {
      // If both are unread we just want to sort by last reply date + time descending.
      if (threadA.tracking.unreadCount && threadB.tracking.unreadCount) {
        if (
          threadA.preview.lastReplyCreatedAt >
          threadB.preview.lastReplyCreatedAt
        ) {
          return -1;
        } else {
          return 1;
        }
      }

      // If one is unread and the other is not, we want to sort the unread one first.
      if (threadA.tracking.unreadCount) {
        return -1;
      }

      if (threadB.tracking.unreadCount) {
        return 1;
      }

      // If both are read, we want to sort by last reply date + time descending.
      if (
        threadA.preview.lastReplyCreatedAt > threadB.preview.lastReplyCreatedAt
      ) {
        return -1;
      } else {
        return 1;
      }
    });
  }

  get shouldRender() {
    return !!this.args.channel;
  }

  @action
  subscribe() {
    this.#unsubscribe();

    this.messageBus.subscribe(
      `/chat/${this.args.channel.id}`,
      this.onMessageBus,
      this.args.channel.messageBusLastId
    );
  }

  @bind
  onMessageBus(busData) {
    switch (busData.type) {
      case "delete":
        this.handleDeleteMessage(busData);
        break;
      case "restore":
        this.handleRestoreMessage(busData);
        break;
    }
  }

  handleDeleteMessage(data) {
    const deletedOriginalMessageThread =
      this.args.channel.threadsManager.threads.findBy(
        "originalMessage.id",
        data.deleted_id
      );

    if (!deletedOriginalMessageThread) {
      return;
    }

    deletedOriginalMessageThread.originalMessage.deletedAt = new Date();
  }

  handleRestoreMessage(data) {
    const restoredOriginalMessageThread =
      this.args.channel.threadsManager.threads.findBy(
        "originalMessage.id",
        data.chat_message.id
      );

    if (!restoredOriginalMessageThread) {
      return;
    }

    restoredOriginalMessageThread.originalMessage.deletedAt = null;
  }

  @action
  loadThreads() {
    this.loading = true;
    this.args.channel.threadsManager.index(this.args.channel.id).finally(() => {
      this.loading = false;
    });
  }

  @action
  teardown() {
    this.loading = true;
    this.#unsubscribe();
  }

  #unsubscribe() {
    this.messageBus.unsubscribe(
      `/chat/${this.args.channel.id}`,
      this.onMessageBus
    );
  }
}
