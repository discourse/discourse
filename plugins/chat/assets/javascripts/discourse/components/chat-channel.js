import { capitalize } from "@ember/string";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import Component from "@glimmer/component";
import { bind, debounce } from "discourse-common/utils/decorators";
import { action } from "@ember/object";
// TODO (martin) Remove this when the handleSentMessage logic inside chatChannelPaneSubscriptionsManager
// is moved over from this file completely.
import { handleStagedMessage } from "discourse/plugins/chat/discourse/services/chat-pane-base-subscriptions-manager";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cancel, later, next, schedule } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import { inject as service } from "@ember/service";
import { Promise } from "rsvp";
import { resetIdle } from "discourse/lib/desktop-notifications";
import {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import { tracked } from "@glimmer/tracking";
import discourseDebounce from "discourse-common/lib/debounce";
import DiscourseURL from "discourse/lib/url";

const PAGE_SIZE = 50;
const PAST = "past";
const FUTURE = "future";
const READ_INTERVAL_MS = 1000;

export default class ChatLivePane extends Component {
  @service capabilities;
  @service chat;
  @service chatChannelsManager;
  @service router;
  @service chatEmojiPickerManager;
  @service chatComposerPresenceManager;
  @service chatStateManager;
  @service("chat-channel-composer") composer;
  @service("chat-channel-pane") pane;
  @service chatChannelPaneSubscriptionsManager;
  @service chatApi;
  @service currentUser;
  @service appEvents;
  @service messageBus;
  @service site;
  @service chatDraftsManager;

  @tracked loading = false;
  @tracked loadingMorePast = false;
  @tracked loadingMoreFuture = false;
  @tracked sending = false;
  @tracked showChatQuoteSuccess = false;
  @tracked includeHeader = true;
  @tracked hasNewMessages = false;
  @tracked needsArrow = false;
  @tracked loadedOnce = false;
  @tracked uploadDropZone;

  scrollable = null;
  _loadedChannelId = null;
  _mentionWarningsSeen = {};
  _unreachableGroupMentions = [];
  _overMembersLimitGroupMentions = [];

  @action
  setUploadDropZone(element) {
    this.uploadDropZone = element;
  }

  @action
  setScrollable(element) {
    this.scrollable = element;
  }

  @action
  setupListeners() {
    document.addEventListener("scroll", this._forceBodyScroll, {
      passive: true,
    });

    onPresenceChange({
      callback: this.onPresenceChangeCallback,
    });
  }

  @action
  teardownListeners() {
    this.#cancelHandlers();
    document.removeEventListener("scroll", this._forceBodyScroll);
    removeOnPresenceChange(this.onPresenceChangeCallback);
    this.unsubscribeToUpdates(this._loadedChannelId);
    this.requestedTargetMessageId = null;
  }

  @action
  didResizePane() {
    this.debounceFillPaneAttempt();
    this.computeDatesSeparators();
    this.forceRendering();
  }

  @action
  resetIdle() {
    resetIdle();
  }

  @action
  didUpdateChannel() {
    this.#cancelHandlers();

    this.loadedOnce = false;

    if (!this.args.channel) {
      return;
    }

    if (
      this.args.channel.isDirectMessageChannel &&
      !this.args.channel.isFollowing
    ) {
      this.chatChannelsManager.follow(this.args.channel);
    }

    // Technically we could keep messages to avoid re-fetching them, but
    // it's not worth the complexity for now
    this.args.channel.clearMessages();

    if (this._loadedChannelId !== this.args.channel.id) {
      this.unsubscribeToUpdates(this._loadedChannelId);
      this.pane.selectingMessages = false;
      this._loadedChannelId = this.args.channel.id;
    }

    const existingDraft = this.chatDraftsManager.get({
      channelId: this.args.channel.id,
    });
    if (existingDraft) {
      this.composer.message = existingDraft;
    } else {
      this.resetComposerMessage();
    }

    this.composer.focus();

    this.loadMessages();
  }

  @action
  loadMessages() {
    if (!this.args.channel?.id) {
      this.loadedOnce = true;
      return;
    }

    if (this.args.targetMessageId) {
      this.requestedTargetMessageId = parseInt(this.args.targetMessageId, 10);
    }

    if (this.requestedTargetMessageId) {
      this.highlightOrFetchMessage(this.requestedTargetMessageId);
    } else {
      this.debounceFetchMessages({ fetchFromLastMessage: false });
    }
  }

  @bind
  onPresenceChangeCallback(present) {
    if (present) {
      this.updateLastReadMessage();
    }
  }

  debounceFetchMessages(options) {
    this._debounceFetchMessagesHandler = discourseDebounce(
      this,
      this.fetchMessages,
      options,
      100
    );
  }

  fetchMessages(options = {}) {
    if (this._selfDeleted) {
      return;
    }

    this.loadingMorePast = true;

    const findArgs = { pageSize: PAGE_SIZE, includeMessages: true };
    const fetchingFromLastRead = !options.fetchFromLastMessage;
    let scrollToMessageId = null;
    if (this.requestedTargetMessageId) {
      findArgs.targetMessageId = this.requestedTargetMessageId;
      scrollToMessageId = this.requestedTargetMessageId;
    } else if (this.requestedTargetDate) {
      findArgs.targetDate = this.requestedTargetDate;
    } else if (fetchingFromLastRead) {
      findArgs.fetchFromLastRead = true;
      scrollToMessageId =
        this.args.channel.currentUserMembership.lastReadMessageId;
    }

    return this.chatApi
      .channel(this.args.channel.id, findArgs)
      .then((result) => {
        if (this._selfDeleted || this.args.channel.id !== result.channel.id) {
          return;
        }

        const [messages, meta] = this.afterFetchCallback(
          this.args.channel,
          result
        );

        this.args.channel.addMessages(messages);
        this.args.channel.details = meta;

        // We update this value server-side when we load the Channel
        // here, so this reflects reality for sidebar unread logic.
        this.args.channel.updateLastViewedAt();

        if (result.threads) {
          result.threads.forEach((thread) => {
            const storedThread = this.args.channel.threadsManager.add(
              this.args.channel,
              thread,
              { replace: true }
            );

            this.#preloadThreadTrackingState(
              storedThread,
              result.tracking.thread_tracking
            );

            const originalMessage = messages.findBy(
              "id",
              storedThread.originalMessage.id
            );
            if (originalMessage) {
              originalMessage.thread = storedThread;
            }
          });
        }

        if (result.unread_thread_overview) {
          this.args.channel.threadsManager.unreadThreadOverview =
            result.unread_thread_overview;
        }

        if (this.requestedTargetMessageId) {
          this.scrollToMessage(scrollToMessageId, {
            highlight: true,
          });
          return;
        } else if (this.requestedTargetDate) {
          const message = this.args.channel?.findFirstMessageOfDay(
            this.requestedTargetDate
          );

          this.scrollToMessage(message.id, {
            highlight: true,
          });
          return;
        }

        if (
          fetchingFromLastRead &&
          messages.length &&
          scrollToMessageId !== messages[messages.length - 1].id
        ) {
          this.scrollToMessage(scrollToMessageId);
          return;
        }
        this.scrollToBottom();
      })
      .catch(this._handleErrors)
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }

        this.loadedOnce = true;
        this.requestedTargetMessageId = null;
        this.requestedTargetDate = null;
        this.loadingMorePast = false;
        this.debounceFillPaneAttempt();
        this.updateLastReadMessage();
        this.subscribeToUpdates(this.args.channel);
      });
  }

  @bind
  fetchMoreMessages({ direction }) {
    const loadingPast = direction === PAST;
    const loadingMoreKey = `loadingMore${capitalize(direction)}`;

    const canLoadMore = loadingPast
      ? this.args.channel?.canLoadMorePast
      : this.args.channel?.canLoadMoreFuture;

    if (
      !canLoadMore ||
      this.loading ||
      this[loadingMoreKey] ||
      !this.args.channel.messages?.length > 0
    ) {
      return Promise.resolve();
    }

    this[loadingMoreKey] = true;

    const messageIndex = loadingPast
      ? 0
      : this.args.channel.messages.length - 1;
    const messageId = this.args.channel.messages[messageIndex].id;
    const findArgs = {
      channelId: this.args.channel.id,
      pageSize: PAGE_SIZE,
      direction,
      messageId,
    };

    return this.chatApi
      .channel(this.args.channel.id, findArgs)
      .then((result) => {
        if (
          this._selfDeleted ||
          this.args.channel.id !== result.meta.channel_id ||
          !this.scrollable
        ) {
          return;
        }

        const [messages, meta] = this.afterFetchCallback(
          this.args.channel,
          result
        );

        if (result.threads) {
          result.threads.forEach((thread) => {
            const storedThread = this.args.channel.threadsManager.add(
              this.args.channel,
              thread,
              { replace: true }
            );

            this.#preloadThreadTrackingState(
              storedThread,
              result.tracking.thread_tracking
            );

            const originalMessage = messages.findBy(
              "id",
              storedThread.originalMessage.id
            );
            if (originalMessage) {
              originalMessage.thread = storedThread;
            }
          });
        }

        if (result.unread_thread_overview) {
          this.args.channel.threadsManager.unreadThreadOverview =
            result.unread_thread_overview;
        }

        this.args.channel.details = meta;

        if (!messages?.length) {
          return;
        }

        this.args.channel.addMessages(messages);

        // Edge case for IOS to avoid blank screens
        // and/or scrolling to bottom losing track of scroll position
        if (!loadingPast && (this.capabilities.isIOS || !this.isScrolling)) {
          this.scrollToMessage(messages[0].id, { position: "end" });
        }
      })
      .catch(this._handleErrors)
      .finally(() => {
        this[loadingMoreKey] = false;
        this.debounceFillPaneAttempt();
      });
  }

  debounceFillPaneAttempt() {
    if (!this.loadedOnce) {
      return;
    }

    this._debouncedFillPaneAttemptHandler = discourseDebounce(
      this,
      this.fillPaneAttempt,
      500
    );
  }

  @bind
  fetchMessagesByDate(date) {
    const message = this.args.channel?.findFirstMessageOfDay(date);
    if (message.firstOfResults && this.args.channel?.canLoadMorePast) {
      this.requestedTargetDate = date;
      this.debounceFetchMessages();
    } else {
      this.highlightOrFetchMessage(message.id);
    }
  }

  fillPaneAttempt() {
    if (this._selfDeleted) {
      return;
    }

    // safeguard
    if (this.args.channel.messages?.length > 200) {
      return;
    }

    if (!this.args.channel?.canLoadMorePast) {
      return;
    }

    const firstMessage = this.args.channel?.messages?.firstObject;
    if (!firstMessage?.visible) {
      return;
    }

    this.fetchMoreMessages({ direction: PAST });
  }

  @bind
  afterFetchCallback(channel, result) {
    const messages = [];
    let foundFirstNew = false;

    result.chat_messages.forEach((messageData, index) => {
      messageData.firstOfResults = index === 0;

      if (this.currentUser.ignored_users) {
        // If a message has been hidden it is because the current user is ignoring
        // the user who sent it, so we want to unconditionally hide it, even if
        // we are going directly to the target
        messageData.hidden = this.currentUser.ignored_users.includes(
          messageData.user.username
        );
      }

      if (this.requestedTargetMessageId === messageData.id) {
        messageData.expanded = !messageData.hidden;
      } else {
        messageData.expanded = !(messageData.hidden || messageData.deleted_at);
      }

      // newest has to be in after fetch callback as we don't want to make it
      // dynamic or it will make the pane jump around, it will disappear on reload
      if (
        !foundFirstNew &&
        messageData.id >
          this.args.channel.currentUserMembership.lastReadMessageId &&
        !channel.messages.some((m) => m.newest)
      ) {
        foundFirstNew = true;
        messageData.newest = true;
      }

      const message = ChatMessage.create(channel, messageData);
      messages.push(message);
    });

    return [messages, result.meta];
  }

  @debounce(100)
  highlightOrFetchMessage(messageId) {
    const message = this.args.channel?.findMessage(messageId);
    if (message) {
      this.scrollToMessage(message.id, {
        highlight: true,
        position: "start",
        autoExpand: true,
      });
      this.requestedTargetMessageId = null;
    } else {
      this.debounceFetchMessages();
    }
  }

  scrollToMessage(
    messageId,
    opts = { highlight: false, position: "start", autoExpand: false }
  ) {
    if (this._selfDeleted) {
      return;
    }

    const message = this.args.channel?.findMessage(messageId);
    if (message?.deletedAt && opts.autoExpand) {
      message.expanded = true;
    }

    schedule("afterRender", () => {
      if (this._selfDeleted) {
        return;
      }

      const messageEl = this.scrollable.querySelector(
        `.chat-message-container[data-id='${messageId}']`
      );

      if (!messageEl) {
        return;
      }

      if (opts.highlight) {
        message.highlighted = true;

        discourseLater(() => {
          if (this._selfDeleted) {
            return;
          }

          message.highlighted = false;
        }, 2000);
      }

      this.forceRendering(() => {
        messageEl.scrollIntoView({
          block: opts.position ?? "center",
        });
      });
    });
  }

  @debounce(READ_INTERVAL_MS)
  updateLastReadMessage() {
    schedule("afterRender", () => {
      if (this._selfDeleted) {
        return;
      }

      const lastReadId =
        this.args.channel.currentUserMembership?.lastReadMessageId;
      let lastUnreadVisibleMessage = this.args.channel.visibleMessages.findLast(
        (message) => !message.staged && (!lastReadId || message.id > lastReadId)
      );

      // all intersecting messages are read
      if (!lastUnreadVisibleMessage) {
        return;
      }

      const element = this.scrollable.querySelector(
        `[data-id='${lastUnreadVisibleMessage.id}']`
      );

      // if the last visible message is not fully visible, we don't want to mark it as read
      // attempt to mark previous one as read
      if (
        element &&
        !this.#isBottomOfMessageVisible(element, this.scrollable)
      ) {
        lastUnreadVisibleMessage = lastUnreadVisibleMessage.previousMessage;

        if (
          !lastUnreadVisibleMessage ||
          lastReadId > lastUnreadVisibleMessage.id
        ) {
          return;
        }
      }

      if (!this.args.channel.isFollowing || !lastUnreadVisibleMessage.id) {
        return;
      }

      if (
        this.args.channel.currentUserMembership.lastReadMessageId >=
        lastUnreadVisibleMessage.id
      ) {
        return;
      }

      return this.chatApi.markChannelAsRead(
        this.args.channel.id,
        lastUnreadVisibleMessage.id
      );
    });
  }

  @action
  scrollToLatestMessage() {
    next(() => {
      schedule("afterRender", () => {
        if (this._selfDeleted) {
          return;
        }

        if (this.args.channel?.canLoadMoreFuture) {
          this._fetchAndScrollToLatest();
        } else if (this.args.channel.messages?.length > 0) {
          this.scrollToMessage(
            this.args.channel.messages[this.args.channel.messages.length - 1].id
          );
        }
      });
    });
  }

  @action
  computeArrow() {
    if (!this.scrollable) {
      return;
    }

    this.needsArrow = Math.abs(this.scrollable.scrollTop) >= 250;
  }

  @action
  computeScrollState() {
    cancel(this._onScrollEndedHandler);

    if (!this.scrollable) {
      return;
    }

    this.chat.activeMessage = null;

    if (this.#isAtTop()) {
      this.fetchMoreMessages({ direction: PAST });
      this.onScrollEnded();
    } else if (this.#isAtBottom()) {
      this.updateLastReadMessage();
      this.hasNewMessages = false;
      this.fetchMoreMessages({ direction: FUTURE });
      this.onScrollEnded();
    } else {
      this.isScrolling = true;
      this._onScrollEndedHandler = discourseLater(
        this,
        this.onScrollEnded,
        150
      );
    }
  }

  @bind
  onScrollEnded() {
    this.isScrolling = false;
  }

  removeMessage(msgData) {
    const message = this.args.channel?.findMessage(msgData.id);
    if (message) {
      this.args.channel?.removeMessage(message);
    }
  }

  @bind
  onMessage(data) {
    switch (data.type) {
      case "sent":
        this.handleSentMessage(data);
        break;
    }
  }

  handleSentMessage(data) {
    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      const stagedMessage = handleStagedMessage(
        this.args.channel,
        this.args.channel.messagesManager,
        data
      );
      if (stagedMessage) {
        return;
      }
    }

    if (this.args.channel?.canLoadMoreFuture) {
      // If we can load more messages, we just notice the user of new messages
      this.hasNewMessages = true;
    } else if (this.#isTowardsBottom()) {
      // If we are at the bottom, we append the message and scroll to it
      const message = ChatMessage.create(this.args.channel, data.chat_message);
      this.args.channel.addMessages([message]);
      this.args.channel.lastMessage = message;
      this.scrollToLatestMessage();
      this.updateLastReadMessage();
    } else {
      // If we are almost at the bottom, we append the message and notice the user
      const message = ChatMessage.create(this.args.channel, data.chat_message);
      this.args.channel.addMessages([message]);
      this.args.channel.lastMessage = message;
      this.hasNewMessages = true;
    }
  }

  get _selfDeleted() {
    return this.isDestroying || this.isDestroyed;
  }

  @action
  async onSendMessage(message) {
    await message.cook();
    if (message.editing) {
      await this.#sendEditMessage(message);
    } else {
      await this.#sendNewMessage(message);
    }
  }

  @action
  resetComposerMessage() {
    this.composer.reset(this.args.channel);
  }

  async #sendEditMessage(message) {
    this.pane.sending = true;

    const data = {
      new_message: message.message,
      upload_ids: message.uploads.map((upload) => upload.id),
    };

    this.resetComposerMessage();

    try {
      return await this.chatApi.editMessage(
        this.args.channel.id,
        message.id,
        data
      );
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.chatDraftsManager.remove({ channelId: this.args.channel.id });
      this.pane.sending = false;
    }
  }

  async #sendNewMessage(message) {
    this.pane.sending = true;

    resetIdle();

    await this.args.channel.stageMessage(message);
    this.resetComposerMessage();

    if (!this.args.channel.canLoadMoreFuture) {
      this.scrollToLatestMessage();
    }

    try {
      await this.chatApi.sendMessage(this.args.channel.id, {
        message: message.message,
        in_reply_to_id: message.inReplyTo?.id,
        staged_id: message.id,
        upload_ids: message.uploads.map((upload) => upload.id),
      });

      this.scrollToLatestMessage();
    } catch (error) {
      this._onSendError(message.id, error);
      this.scrollToBottom();
    } finally {
      if (!this._selfDeleted) {
        this.chatDraftsManager.remove({ channelId: this.args.channel.id });
        this.pane.sending = false;
      }
    }
  }

  _onSendError(id, error) {
    const stagedMessage = this.args.channel.findStagedMessage(id);
    if (stagedMessage) {
      if (error.jqXHR?.responseJSON?.errors?.length) {
        // only network errors are retryable
        stagedMessage.message = "";
        stagedMessage.cooked = "";
        stagedMessage.error = error.jqXHR.responseJSON.errors[0];
      } else {
        this.chat.markNetworkAsUnreliable();
        stagedMessage.error = "network_error";
      }
    }

    this.resetComposerMessage();
  }

  @action
  resendStagedMessage(stagedMessage) {
    this.pane.sending = true;

    stagedMessage.error = null;

    const data = {
      cooked: stagedMessage.cooked,
      message: stagedMessage.message,
      upload_ids: stagedMessage.uploads.map((upload) => upload.id),
      staged_id: stagedMessage.id,
    };

    this.chatApi
      .sendMessage(this.args.channel.id, data)
      .catch((error) => {
        this._onSendError(data.staged_id, error);
      })
      .then(() => {
        this.chat.markNetworkAsReliable();
      })
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }
        this.pane.sending = false;
      });
  }

  get chatProgressBarContainer() {
    return document.querySelector("#chat-progress-bar-container");
  }

  @action
  onCloseFullScreen() {
    this.chatStateManager.prefersDrawer();

    DiscourseURL.routeTo(this.chatStateManager.lastKnownAppURL).then(() => {
      DiscourseURL.routeTo(this.chatStateManager.lastKnownChatURL);
    });
  }

  unsubscribeToUpdates(channelId) {
    if (!channelId) {
      return;
    }

    this.chatChannelPaneSubscriptionsManager.unsubscribe();
    this.messageBus.unsubscribe(`/chat/${channelId}`, this.onMessage);
  }

  subscribeToUpdates(channel) {
    if (!channel) {
      return;
    }

    this.unsubscribeToUpdates(channel.id);
    this.messageBus.subscribe(
      `/chat/${channel.id}`,
      this.onMessage,
      channel.channelMessageBusLastId
    );
    this.chatChannelPaneSubscriptionsManager.subscribe(channel);
  }

  @bind
  _forceBodyScroll() {
    // when keyboard is visible this will ensure body
    // doesn’t scroll out of viewport
    if (
      this.capabilities.isIOS &&
      document.documentElement.classList.contains("keyboard-visible") &&
      !isZoomed()
    ) {
      document.documentElement.scrollTo(0, 0);
    }
  }

  _fetchAndScrollToLatest() {
    this.loadedOnce = false;
    return this.debounceFetchMessages({
      fetchFromLastMessage: true,
    });
  }

  @bind
  _handleErrors(error) {
    switch (error?.jqXHR?.status) {
      case 429:
        popupAjaxError(error);
        break;
      case 404:
        // avoids handling 404 errors from a channel
        // that is not the current one, this is very likely in tests
        // which will destroy the channel after the test is done
        if (
          this.args.channel?.id &&
          error.jqXHR?.requestedUrl ===
            `/chat/api/channels/${this.args.channel.id}`
        ) {
          popupAjaxError(error);
        }
        break;
      default:
        throw error;
    }
  }

  @action
  addAutoFocusEventListener() {
    document.addEventListener("keydown", this._autoFocus);
  }

  @action
  removeAutoFocusEventListener() {
    document.removeEventListener("keydown", this._autoFocus);
  }

  @bind
  _autoFocus(event) {
    if (this.chatStateManager.isDrawerActive) {
      return;
    }

    const { key, metaKey, ctrlKey, code, target } = event;

    if (
      !key ||
      // Handles things like Enter, Tab, Shift
      key.length > 1 ||
      // Don't need to focus if the user is beginning a shortcut.
      metaKey ||
      ctrlKey ||
      // Space's key comes through as ' ' so it's not covered by key
      code === "Space" ||
      // ? is used for the keyboard shortcut modal
      key === "?"
    ) {
      return;
    }

    if (!target || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName)) {
      return;
    }

    event.preventDefault();
    this.composer.focus({ addText: event.key });
    return;
  }

  @action
  computeDatesSeparators() {
    cancel(this._laterComputeHandler);
    this._computeDatesSeparators();
    this._laterComputeHandler = later(this, this._computeDatesSeparators, 100);
  }

  // A more consistent way to scroll to the bottom when we are sure this is our goal
  // it will also limit issues with any element changing the height while we are scrolling
  // to the bottom
  @action
  scrollToBottom() {
    if (!this.scrollable) {
      return;
    }

    this.scrollable.scrollTop = -1;
    this.forceRendering(() => {
      this.scrollable.scrollTop = 0;
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

  _computeDatesSeparators() {
    schedule("afterRender", () => {
      if (this._selfDeleted) {
        return;
      }

      if (!this.scrollable) {
        return;
      }

      const dates = [
        ...this.scrollable.querySelectorAll(".chat-message-separator-date"),
      ].reverse();
      const height = this.scrollable.querySelector(
        ".chat-messages-container"
      ).clientHeight;

      dates
        .map((date, index) => {
          const item = { bottom: 0, date };
          const line = date.nextElementSibling;

          if (index > 0) {
            const prevDate = dates[index - 1];
            const prevLine = prevDate.nextElementSibling;
            item.bottom = height - prevLine.offsetTop;
          }

          if (dates.length === 1) {
            item.height = height;
          } else {
            if (index === 0) {
              item.height = height - line.offsetTop;
            } else {
              const prevDate = dates[index - 1];
              const prevLine = prevDate.nextElementSibling;
              item.height =
                height - line.offsetTop - (height - prevLine.offsetTop);
            }
          }

          return item;
        })
        // group all writes at the end
        .forEach((item) => {
          item.date.style.bottom = item.bottom + "px";
          item.date.style.height = item.height + "px";
        });
    });
  }

  #isAtBottom() {
    if (!this.scrollable) {
      return false;
    }

    return Math.abs(this.scrollable.scrollTop) <= 2;
  }

  #isTowardsBottom() {
    if (!this.scrollable) {
      return false;
    }

    return Math.abs(this.scrollable.scrollTop) <= 50;
  }

  #isAtTop() {
    if (!this.scrollable) {
      return false;
    }

    return (
      Math.abs(this.scrollable.scrollTop) >=
      this.scrollable.scrollHeight - this.scrollable.offsetHeight - 2
    );
  }

  #isBottomOfMessageVisible(element, container) {
    const rect = element.getBoundingClientRect();
    const containerRect = container.getBoundingClientRect();
    // - 5.0 to account for rounding errors, especially on firefox
    return rect.bottom - 5.0 <= containerRect.bottom;
  }

  #cancelHandlers() {
    cancel(this._debouncedFillPaneAttemptHandler);
    cancel(this._onScrollEndedHandler);
    cancel(this._laterComputeHandler);
    cancel(this._debounceFetchMessagesHandler);
  }

  #preloadThreadTrackingState(storedThread, threadTracking) {
    if (!threadTracking[storedThread.id]) {
      return;
    }

    storedThread.tracking.unreadCount =
      threadTracking[storedThread.id].unread_count;
    storedThread.tracking.mentionCount =
      threadTracking[storedThread.id].mention_count;
  }
}
