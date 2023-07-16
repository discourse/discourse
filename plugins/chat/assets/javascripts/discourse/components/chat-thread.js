import Component from "@glimmer/component";
import { NotificationLevels } from "discourse/lib/notification-levels";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";
import { Promise } from "rsvp";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind, debounce } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { cancel, next, schedule } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import { resetIdle } from "discourse/lib/desktop-notifications";

const PAGE_SIZE = 50;
const FUTURE = "future";
const PAST = "past";
const READ_INTERVAL_MS = 1000;

export default class ChatThreadPanel extends Component {
  @service siteSettings;
  @service currentUser;
  @service chat;
  @service router;
  @service chatApi;
  @service chatComposerPresenceManager;
  @service chatThreadComposer;
  @service chatThreadPane;
  @service chatThreadPaneSubscriptionsManager;
  @service appEvents;
  @service capabilities;
  @service chatHistory;

  @tracked loading;
  @tracked uploadDropZone;
  @tracked canLoadMoreFuture;
  @tracked canLoadMorePast;

  scrollable = null;

  @action
  handleKeydown(event) {
    if (event.key === "Escape") {
      return this.router.transitionTo(
        "chat.channel",
        ...this.args.thread.channel.routeModels
      );
    }
  }

  @action
  didUpdateThread() {
    this.subscribeToUpdates();
    this.chatThreadComposer.focus();
    this.loadMessages();
    this.resetComposerMessage();
  }

  @action
  setUploadDropZone(element) {
    this.uploadDropZone = element;
  }

  @action
  subscribeToUpdates() {
    this.chatThreadPaneSubscriptionsManager.subscribe(this.args.thread);
  }

  @action
  unsubscribeFromUpdates() {
    this.chatThreadPaneSubscriptionsManager.unsubscribe();
  }

  @action
  computeScrollState() {
    cancel(this.onScrollEndedHandler);

    if (!this.scrollable) {
      return;
    }

    this.chat.activeMessage = null;

    if (this.#isAtBottom()) {
      this.updateLastReadMessage();
      this.fetchMoreMessages({ direction: FUTURE });
      this.onScrollEnded();
    } else {
      this.isScrolling = true;
      this.onScrollEndedHandler = discourseLater(this, this.onScrollEnded, 150);
    }
  }

  #isAtBottom() {
    if (!this.scrollable) {
      return false;
    }

    // This is different from the channel scrolling because the scrolling here
    // is inverted -- in the channel's case scrollTop is 0 when scrolled to the
    // bottom of the channel, but in the negatives when scrolling up to past messages.
    //
    // c.f. https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollHeight#determine_if_an_element_has_been_totally_scrolled
    return (
      Math.abs(
        this.scrollable.scrollHeight -
          this.scrollable.clientHeight -
          this.scrollable.scrollTop
      ) <= 2
    );
  }

  @bind
  onScrollEnded() {
    this.isScrolling = false;
  }

  @debounce(READ_INTERVAL_MS)
  updateLastReadMessage() {
    schedule("afterRender", () => {
      if (this._selfDeleted) {
        return;
      }

      // HACK: We don't have proper scroll visibility over
      // what message we are looking at, don't have the lastReadMessageId
      // for the thread, and this updateLastReadMessage function is only
      // called when scrolling all the way to the bottom.
      this.markThreadAsRead();
    });
  }

  @action
  setScrollable(element) {
    this.scrollable = element;
  }

  @action
  loadMessages() {
    this.args.thread.messagesManager.clearMessages();
    this.fetchMessages();
  }

  @action
  didResizePane() {
    this.forceRendering();
  }

  get _selfDeleted() {
    return this.isDestroying || this.isDestroyed;
  }

  @debounce(100)
  fetchMessages() {
    if (this._selfDeleted) {
      return Promise.resolve();
    }

    if (this.args.thread.staged) {
      const message = this.args.thread.originalMessage;
      message.thread = this.args.thread;
      this.args.thread.messagesManager.addMessages([message]);
      return Promise.resolve();
    }

    this.loading = true;

    const findArgs = {
      pageSize: PAGE_SIZE,
      threadId: this.args.thread.id,
      includeMessages: true,
      direction: FUTURE,
    };
    return this.chatApi
      .channel(this.args.thread.channel.id, findArgs)
      .then((result) => {
        if (this._selfDeleted) {
          return;
        }

        if (this.args.thread.channel.id !== result.meta.channel_id) {
          if (this.chatHistory.previousRoute?.name === "chat.channel.index") {
            this.router.transitionTo(
              "chat.channel",
              "-",
              result.meta.channel_id
            );
          } else {
            this.router.transitionTo("chat.channel.threads");
          }
        }

        const [messages, meta] = this.afterFetchCallback(
          this.args.thread,
          result
        );
        this.args.thread.messagesManager.addMessages(messages);
        this.canLoadMorePast = result.meta.can_load_more_past;
        this.canLoadMoreFuture = result.meta.can_load_more_future;
        this.args.thread.details = meta;
        this.markThreadAsRead();
      })
      .catch(this.#handleErrors)
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }

        this.loading = false;
      });
  }

  @action
  fetchMoreMessages({ direction }) {
    const loadingPast = direction === PAST;

    const canLoadMore = loadingPast
      ? this.canLoadMorePast
      : this.canLoadMoreFuture;

    if (!canLoadMore) {
      return Promise.resolve();
    }
    this.loading = true;

    const messageIndex = loadingPast ? 0 : this.args.thread.messages.length - 1;
    const messageId = this.args.thread.messages[messageIndex].id;

    const findArgs = {
      threadId: this.args.thread.id,
      pageSize: PAGE_SIZE,
      includeMessages: true,
      direction: FUTURE,
      messageId,
    };

    return this.chatApi
      .channel(this.args.thread.channel.id, findArgs)
      .then((result) => {
        const [messages, meta] = this.afterFetchCallback(
          this.args.thread,
          result
        );
        this.args.thread.messagesManager.addMessages(messages);
        this.canLoadMorePast = result.meta.can_load_more_past;
        this.canLoadMoreFuture = result.meta.can_load_more_future;

        this.args.thread.details = meta;
      })
      .catch(this.#handleErrors)
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }
        this.loading = false;
      });
  }

  @bind
  afterFetchCallback(thread, result) {
    const messages = [];

    result.chat_messages.forEach((messageData) => {
      // If a message has been hidden it is because the current user is ignoring
      // the user who sent it, so we want to unconditionally hide it, even if
      // we are going directly to the target
      if (this.currentUser.ignored_users) {
        messageData.hidden = this.currentUser.ignored_users.includes(
          messageData.user.username
        );
      }

      messageData.expanded = !(messageData.hidden || messageData.deleted_at);
      const message = ChatMessage.create(thread.channel, messageData);
      message.thread = thread;
      messages.push(message);
    });

    return [messages, result.meta];
  }

  // NOTE: At some point we want to do this based on visible messages
  // and scrolling; for now it's enough to do it when the thread panel
  // opens/messages are loaded since we have no pagination for threads.
  markThreadAsRead() {
    return this.chatApi.markThreadAsRead(
      this.args.thread.channel.id,
      this.args.thread.id
    );
  }

  @action
  async onSendMessage(message) {
    resetIdle();

    await message.cook();
    if (message.editing) {
      await this.#sendEditMessage(message);
    } else {
      await this.#sendNewMessage(message);
    }
  }

  @action
  resetComposerMessage() {
    this.chatThreadComposer.reset(this.args.thread);
  }

  async #sendNewMessage(message) {
    if (this.chatThreadPane.sending) {
      return;
    }

    this.chatThreadPane.sending = true;
    await this.args.thread.stageMessage(message);
    this.resetComposerMessage();
    this.scrollToBottom();

    try {
      await this.chatApi
        .sendMessage(this.args.thread.channel.id, {
          message: message.message,
          in_reply_to_id: message.thread.staged
            ? message.thread.originalMessage.id
            : null,
          staged_id: message.id,
          upload_ids: message.uploads.map((upload) => upload.id),
          thread_id: message.thread.staged ? null : message.thread.id,
          staged_thread_id: message.thread.staged ? message.thread.id : null,
        })
        .then((response) => {
          this.args.thread.currentUserMembership ??=
            UserChatThreadMembership.create({
              notification_level: NotificationLevels.TRACKING,
              last_read_message_id: response.message_id,
            });
        })
        .catch((error) => {
          this.#onSendError(message.id, error);
        })
        .finally(() => {
          if (this._selfDeleted) {
            return;
          }
          this.chatThreadPane.sending = false;
        });
    } catch (error) {
      this.#onSendError(message.id, error);
    } finally {
      if (!this._selfDeleted) {
        this.chatThreadPane.sending = false;
      }
    }
  }

  async #sendEditMessage(message) {
    this.chatThreadPane.sending = true;

    const data = {
      new_message: message.message,
      upload_ids: message.uploads.map((upload) => upload.id),
    };

    this.resetComposerMessage();

    try {
      return await this.chatApi.editMessage(
        message.channel.id,
        message.id,
        data
      );
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.chatThreadPane.sending = false;
    }
  }

  // A more consistent way to scroll to the bottom when we are sure this is our goal
  // it will also limit issues with any element changing the height while we are scrolling
  // to the bottom
  @action
  scrollToBottom() {
    next(() => {
      schedule("afterRender", () => {
        if (!this.scrollable) {
          return;
        }

        this.scrollable.scrollTop = this.scrollable.scrollHeight + 1;
        this.forceRendering(() => {
          this.scrollable.scrollTop = this.scrollable.scrollHeight;
        });
      });
    });
  }

  // since -webkit-overflow-scrolling: touch can't be used anymore to disable momentum scrolling
  // we now use this hack to disable it
  @bind
  forceRendering(callback) {
    if (this.capabilities.isIOS) {
      this.scrollable.style.overflow = "hidden";
    }

    callback?.();

    if (this.capabilities.isIOS) {
      next(() => {
        schedule("afterRender", () => {
          if (this._selfDeleted || !this.scrollable) {
            return;
          }
          this.scrollable.style.overflow = "auto";
        });
      });
    }
  }

  @action
  resendStagedMessage() {}

  #handleErrors(error) {
    switch (error?.jqXHR?.status) {
      case 429:
      case 404:
        popupAjaxError(error);
        break;
      default:
        throw error;
    }
  }

  #onSendError(stagedId, error) {
    const stagedMessage =
      this.args.thread.messagesManager.findStagedMessage(stagedId);
    if (stagedMessage) {
      if (error.jqXHR?.responseJSON?.errors?.length) {
        stagedMessage.error = error.jqXHR.responseJSON.errors[0];
      } else {
        this.chat.markNetworkAsUnreliable();
        stagedMessage.error = "network_error";
      }
    }

    this.resetComposerMessage();
  }
}
