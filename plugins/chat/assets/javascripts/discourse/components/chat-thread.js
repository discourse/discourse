import Component from "@glimmer/component";
import { NotificationLevels } from "discourse/lib/notification-levels";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { cancel, next } from "@ember/runloop";
import { resetIdle } from "discourse/lib/desktop-notifications";
import ChatMessagesLoader from "discourse/plugins/chat/discourse/lib/chat-messages-loader";
import { getOwner } from "discourse-common/lib/get-owner";
import {
  FUTURE,
  PAST,
  READ_INTERVAL_MS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import discourseDebounce from "discourse-common/lib/debounce";
import {
  bodyScrollFix,
  stackingContextFix,
} from "discourse/plugins/chat/discourse/lib/chat-ios-hacks";
import {
  scrollListToBottom,
  scrollListToMessage,
  scrollListToTop,
} from "discourse/plugins/chat/discourse/lib/scroll-helpers";

export default class ChatThread extends Component {
  @service appEvents;
  @service capabilities;
  @service chat;
  @service chatApi;
  @service chatComposerPresenceManager;
  @service chatHistory;
  @service chatThreadComposer;
  @service chatThreadPane;
  @service chatThreadPaneSubscriptionsManager;
  @service currentUser;
  @service router;
  @service siteSettings;

  @tracked isAtBottom = true;
  @tracked isScrolling = false;
  @tracked needsArrow = false;
  @tracked uploadDropZone;

  scrollable = null;

  @action
  resetIdle() {
    resetIdle();
  }

  @cached
  get messagesLoader() {
    return new ChatMessagesLoader(getOwner(this), this.args.thread);
  }

  get messagesManager() {
    return this.args.thread.messagesManager;
  }

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
    this.messagesManager.clear();
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
  teardown() {
    this.chatThreadPaneSubscriptionsManager.unsubscribe();
    cancel(this._debouncedFillPaneAttemptHandler);
    cancel(this._debounceUpdateLastReadMessageHandler);
  }

  @action
  onScroll(state) {
    next(() => {
      if (this.#flushIgnoreNextScroll()) {
        return;
      }

      bodyScrollFix();

      this.needsArrow =
        (this.messagesLoader.fetchedOnce &&
          this.messagesLoader.canLoadMoreFuture) ||
        (state.distanceToBottom.pixels > 250 && !state.atBottom);
      this.isScrolling = true;
      this.debounceUpdateLastReadMessage();

      if (
        state.atTop ||
        (!this.capabilities.isIOS &&
          state.up &&
          state.distanceToTop.percentage < 40)
      ) {
        this.fetchMoreMessages({ direction: PAST });
      } else if (state.atBottom) {
        this.fetchMoreMessages({ direction: FUTURE });
      }
    });
  }

  @action
  onScrollEnd(state) {
    this.needsArrow =
      (this.messagesLoader.fetchedOnce &&
        this.messagesLoader.canLoadMoreFuture) ||
      (state.distanceToBottom.pixels > 250 && !state.atBottom);
    this.isScrolling = false;
    this.resetIdle();
    this.atBottom = state.atBottom;

    if (state.atBottom) {
      this.fetchMoreMessages({ direction: FUTURE });
    }
  }

  debounceUpdateLastReadMessage() {
    this._debounceUpdateLastReadMessageHandler = discourseDebounce(
      this,
      this.updateLastReadMessage,
      READ_INTERVAL_MS
    );
  }

  @bind
  updateLastReadMessage() {
    // HACK: We don't have proper scroll visibility over
    // what message we are looking at, don't have the lastReadMessageId
    // for the thread, and this updateLastReadMessage function is only
    // called when scrolling all the way to the bottom.
    this.markThreadAsRead();
  }

  @action
  setScrollable(element) {
    this.scrollable = element;
  }

  @action
  loadMessages() {
    this.fetchMessages();
    this.subscribeToUpdates();
  }

  @action
  didResizePane() {
    this._ignoreNextScroll = true;
    this.debounceFillPaneAttempt();
    this.debounceUpdateLastReadMessage();
  }

  async fetchMessages(findArgs = {}) {
    if (this.args.thread.staged) {
      const message = this.args.thread.originalMessage;
      message.thread = this.args.thread;
      message.manager = this.messagesManager;
      this.messagesManager.addMessages([message]);
      return;
    }

    if (this.messagesLoader.loading) {
      return;
    }

    this.messagesManager.clear();

    findArgs.targetMessageId ??=
      this.args.targetMessageId ||
      this.args.thread.currentUserMembership?.lastReadMessageId;

    if (!findArgs.targetMessageId) {
      findArgs.direction = FUTURE;
    }

    const result = await this.messagesLoader.load(findArgs);
    if (!result) {
      return;
    }

    const [messages, meta] = this.processMessages(this.args.thread, result);
    stackingContextFix(this.scrollable, () => {
      this.messagesManager.addMessages(messages);
    });
    this.args.thread.details = meta;

    if (this.args.targetMessageId) {
      this.scrollToMessageId(this.args.targetMessageId, { highlight: true });
    } else if (this.args.thread.currentUserMembership?.lastReadMessageId) {
      this.scrollToMessageId(
        this.args.thread.currentUserMembership?.lastReadMessageId
      );
    } else {
      this.scrollToTop();
    }

    this.debounceFillPaneAttempt();
  }

  @action
  async fetchMoreMessages({ direction }) {
    if (this.messagesLoader.loading) {
      return;
    }

    const result = await this.messagesLoader.loadMore({ direction });
    if (!result) {
      return;
    }

    const [messages, meta] = this.processMessages(this.args.thread, result);
    if (!messages?.length) {
      return;
    }

    stackingContextFix(this.scrollable, () => {
      this.messagesManager.addMessages(messages);
    });
    this.args.thread.details = meta;

    if (direction === FUTURE) {
      this.scrollToMessageId(messages.firstObject.id, {
        position: "end",
        behavior: "auto",
      });
    } else if (direction === PAST) {
      this.scrollToMessageId(messages.lastObject.id);
    }

    this.debounceFillPaneAttempt();
  }

  @action
  scrollToLatestMessage() {
    if (this.messagesLoader.canLoadMoreFuture) {
      this.fetchMessages();
    } else if (this.messagesManager.messages.length > 0) {
      this.scrollToBottom();
    }
  }

  debounceFillPaneAttempt() {
    if (!this.messagesLoader.fetchedOnce) {
      return;
    }

    this._debouncedFillPaneAttemptHandler = discourseDebounce(
      this,
      this.fillPaneAttempt,
      500
    );
  }

  async fillPaneAttempt() {
    // safeguard
    if (this.messagesManager.messages.length > 200) {
      return;
    }

    if (!this.messagesLoader.canLoadMorePast) {
      return;
    }

    const firstMessage = this.messagesManager.messages.firstObject;
    if (!firstMessage?.visible) {
      return;
    }

    await this.fetchMoreMessages({ direction: PAST });
  }

  scrollToMessageId(
    messageId,
    opts = { highlight: false, position: "start", autoExpand: false }
  ) {
    this._ignoreNextScroll = true;
    const message = this.messagesManager.findMessage(messageId);
    scrollListToMessage(this.scrollable, message, opts);
  }

  @bind
  processMessages(thread, result) {
    const messages = result.messages.map((messageData) => {
      const ignored = this.currentUser.ignored_users || [];
      const hidden = ignored.includes(messageData.user.username);

      return ChatMessage.create(thread.channel, {
        ...messageData,
        hidden,
        expanded: !(hidden || messageData.deleted_at),
        manager: this.messagesManager,
        thread,
      });
    });

    return [messages, result.meta];
  }

  // NOTE: At some point we want to do this based on visible messages
  // and scrolling; for now it's enough to do it when the thread panel
  // opens/messages are loaded since we have no pagination for threads.
  markThreadAsRead() {
    if (!this.args.thread || this.args.thread.staged) {
      return;
    }

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
    this._ignoreNextScroll = true;
    stackingContextFix(this.scrollable, async () => {
      await this.args.thread.stageMessage(message);
    });
    this.resetComposerMessage();

    if (!this.messagesLoader.canLoadMoreFuture) {
      this.scrollToLatestMessage();
    }

    try {
      const response = await this.chatApi.sendMessage(
        this.args.thread.channel.id,
        {
          message: message.message,
          in_reply_to_id: message.thread.staged
            ? message.thread.originalMessage?.id
            : null,
          staged_id: message.id,
          upload_ids: message.uploads.map((upload) => upload.id),
          thread_id: message.thread.staged ? null : message.thread.id,
          staged_thread_id: message.thread.staged ? message.thread.id : null,
        }
      );

      this.args.thread.currentUserMembership ??=
        UserChatThreadMembership.create({
          notification_level: NotificationLevels.TRACKING,
          last_read_message_id: response.message_id,
        });

      this.scrollToLatestMessage();
    } catch (error) {
      this.#onSendError(message.id, error);
    } finally {
      this.chatThreadPane.sending = false;
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

  @action
  scrollToBottom() {
    this._ignoreNextScroll = true;
    scrollListToBottom(this.scrollable);
  }

  @action
  scrollToTop() {
    this._ignoreNextScroll = true;
    scrollListToTop(this.scrollable);
  }

  @action
  resendStagedMessage() {}

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

  #flushIgnoreNextScroll() {
    const prev = this._ignoreNextScroll;
    this._ignoreNextScroll = false;
    return prev;
  }
}
