import Component from "@glimmer/component";
import { bind } from "discourse-common/utils/decorators";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatThreadList extends Component {
  @service chat;
  @service chatApi;
  @service messageBus;
  @service chatTrackingStateManager;

  get threadsManager() {
    return this.args.channel.threadsManager;
  }

  // NOTE: This replicates sort logic from the server. We need this because
  // the thread unread count + last reply date + time update when new messages
  // are sent to the thread, and we want the list to react in realtime to this.
  get sortedThreads() {
    return this.threadsManager.threads
      .filter(
        (thread) =>
          thread.currentUserMembership && !thread.originalMessage.deletedAt
      )
      .sort((threadA, threadB) => {
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
          threadA.preview.lastReplyCreatedAt >
          threadB.preview.lastReplyCreatedAt
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
  loadThreads() {
    return this.threadsCollection.load({ limit: 10 });
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
    const deletedOriginalMessageThread = this.threadsManager.threads.findBy(
      "originalMessage.id",
      data.deleted_id
    );

    if (!deletedOriginalMessageThread) {
      return;
    }

    deletedOriginalMessageThread.originalMessage.deletedAt = new Date();
  }

  handleRestoreMessage(data) {
    const restoredOriginalMessageThread = this.threadsManager.threads.findBy(
      "originalMessage.id",
      data.chat_message.id
    );

    if (!restoredOriginalMessageThread) {
      return;
    }

    restoredOriginalMessageThread.originalMessage.deletedAt = null;
  }

  @cached
  get threadsCollection() {
    return this.chatApi.threads(this.args.channel.id, this.handleLoadedThreads);
  }

  @bind
  handleLoadedThreads(result) {
    return result.threads.map((thread) => {
      const threadModel = this.threadsManager.add(this.args.channel, thread, {
        replace: true,
      });

      this.chatTrackingStateManager.setupChannelThreadState(
        this.args.channel,
        result.tracking
      );

      return threadModel;
    });
  }

  @action
  teardown() {
    this.#unsubscribe();
  }

  #unsubscribe() {
    // TODO (joffrey) In drawer we won't have channel anymore at this point
    if (!this.args.channel) {
      return;
    }

    this.messageBus.unsubscribe(
      `/chat/${this.args.channel.id}`,
      this.onMessageBus
    );
  }
}
