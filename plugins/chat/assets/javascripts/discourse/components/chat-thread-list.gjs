import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import { eq } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import ChatThreadListItem from "discourse/plugins/chat/discourse/components/chat/thread-list/item";
import ChatTrackMessage from "discourse/plugins/chat/discourse/modifiers/chat/track-message";

export default class ChatThreadList extends Component {
  @service chat;
  @service chatApi;
  @service messageBus;
  @service chatTrackingStateManager;

  noThreadsLabel = i18n("chat.threads.none");

  subscribe = modifierFn((element, [channel]) => {
    this.messageBus.subscribe(
      `/chat/${channel.id}`,
      this.onMessageBus,
      channel.channelMessageBusLastId
    );

    return () => {
      // TODO (joffrey) In drawer we won't have channel anymore at this point
      if (!channel) {
        return;
      }

      this.messageBus.unsubscribe(`/chat/${channel.id}`, this.onMessageBus);
    };
  });

  fill = modifierFn((element) => {
    this.resizeObserver = new ResizeObserver(() => {
      if (isElementInViewport(element)) {
        this.loadThreads();
      }
    });

    this.resizeObserver.observe(element);

    return () => {
      this.resizeObserver.disconnect();
    };
  });

  loadMore = modifierFn((element) => {
    this.intersectionObserver = new IntersectionObserver(this.loadThreads);
    this.intersectionObserver.observe(element);

    return () => {
      this.intersectionObserver.disconnect();
    };
  });

  @cached
  get threadsCollection() {
    return this.chatApi.threads(this.args.channel.id, this.handleLoadedThreads);
  }

  @bind
  loadThreads() {
    this.threadsCollection.load({ limit: 10 });
  }

  get threadsManager() {
    return this.args.channel.threadsManager;
  }

  // NOTE: This replicates sort logic from the server. We need this because
  // the thread unread count + last reply date + time update when new messages
  // are sent to the thread, and we want the list to react in realtime to this.
  @cached
  get sortedThreads() {
    return this.threadsManager.threads
      .filter(
        (thread) =>
          !thread.originalMessage.deletedAt &&
          thread.originalMessage?.id !== thread.lastMessageId
      )
      .sort((threadA, threadB) => {
        // if both threads have watched unread count, then show latest first
        if (
          threadA.tracking.watchedThreadsUnreadCount &&
          threadB.tracking.watchedThreadsUnreadCount
        ) {
          if (
            threadA.preview.lastReplyCreatedAt >
            threadB.preview.lastReplyCreatedAt
          ) {
            return -1;
          } else {
            return 1;
          }
        }

        // sort threads by watched unread count
        if (threadA.tracking.watchedThreadsUnreadCount) {
          return -1;
        }

        if (threadB.tracking.watchedThreadsUnreadCount) {
          return 1;
        }

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

  get lastThread() {
    return this.sortedThreads[this.sortedThreads.length - 1];
  }

  get shouldRender() {
    return !!this.args.channel;
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

  <template>
    {{#if this.shouldRender}}
      <div class="chat-thread-list" {{this.subscribe @channel}}>
        <div class="chat-thread-list__items" {{this.fill}}>

          {{#each this.sortedThreads key="id" as |thread|}}
            <ChatThreadListItem
              @thread={{thread}}
              {{(if
                (eq thread this.lastThread)
                (modifier ChatTrackMessage this.load)
              )}}
            />
          {{else}}
            {{#if this.threadsCollection.fetchedOnce}}
              <div class="chat-thread-list__no-threads">
                {{this.noThreadsLabel}}
              </div>
            {{/if}}
          {{/each}}

          <ConditionalLoadingSpinner
            @condition={{this.threadsCollection.loading}}
          />

          <div {{this.loadMore}}>
            <br />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
