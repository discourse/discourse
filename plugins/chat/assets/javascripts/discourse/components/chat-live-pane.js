import { capitalize } from "@ember/string";
import { cloneJSON } from "discourse-common/lib/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatMessageDraft from "discourse/plugins/chat/discourse/models/chat-message-draft";
import Component from "@glimmer/component";
import { bind, debounce } from "discourse-common/utils/decorators";
import { action } from "@ember/object";
// TODO (martin) Remove this when the handleSentMessage logic inside chatChannelPaneSubscriptionsManager
// is moved over from this file completely.
import { handleStagedMessage } from "discourse/plugins/chat/discourse/services/chat-pane-base-subscriptions-manager";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cancel, schedule, throttle } from "@ember/runloop";
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
  @service chatChannelComposer;
  @service chatChannelPane;
  @service chatChannelPaneSubscriptionsManager;
  @service chatApi;
  @service currentUser;
  @service appEvents;
  @service messageBus;
  @service site;

  @tracked loading = false;
  @tracked loadingMorePast = false;
  @tracked loadingMoreFuture = false;
  @tracked sendingLoading = false;
  @tracked showChatQuoteSuccess = false;
  @tracked includeHeader = true;
  @tracked hasNewMessages = false;
  @tracked needsArrow = false;
  @tracked loadedOnce = false;

  scrollable = null;
  _loadedChannelId = null;
  _mentionWarningsSeen = {};
  _unreachableGroupMentions = [];
  _overMembersLimitGroupMentions = [];

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
    document.removeEventListener("scroll", this._forceBodyScroll);
    removeOnPresenceChange(this.onPresenceChangeCallback);
    this._unsubscribeToUpdates(this._loadedChannelId);
    this.requestedTargetMessageId = null;
  }

  @action
  didResizePane() {
    this.fillPaneAttempt();
    this.computeDatesSeparators();
    this.forceRendering();
  }

  @action
  resetIdle() {
    resetIdle();
  }

  @action
  updateChannel() {
    this.loadedOnce = false;

    // Technically we could keep messages to avoid re-fetching them, but
    // it's not worth the complexity for now
    this.args.channel?.messagesManager?.clearMessages();

    if (this._loadedChannelId !== this.args.channel?.id) {
      this._unsubscribeToUpdates(this._loadedChannelId);
      this.chatChannelPane.selectingMessages = false;
      this.chatChannelComposer.cancelEditing();
      this._loadedChannelId = this.args.channel?.id;
    }

    this.loadMessages();
    this._subscribeToUpdates(this.args.channel);
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
      this.fetchMessages({ fetchFromLastMessage: false });
    }
  }

  @bind
  onPresenceChangeCallback(present) {
    if (present) {
      this.updateLastReadMessage();
    }
  }

  @debounce(100)
  fetchMessages(options = {}) {
    if (this._selfDeleted) {
      return;
    }

    this.loadingMorePast = true;

    const findArgs = { pageSize: PAGE_SIZE };
    const fetchingFromLastRead = !options.fetchFromLastMessage;
    if (this.requestedTargetMessageId) {
      findArgs["targetMessageId"] = this.requestedTargetMessageId;
    } else if (fetchingFromLastRead) {
      findArgs["targetMessageId"] =
        this.args.channel.currentUserMembership.last_read_message_id;
    }

    return this.chatApi
      .messages(this.args.channel.id, findArgs)
      .then((results) => {
        if (
          this._selfDeleted ||
          this.args.channel.id !== results.meta.channel_id
        ) {
          return;
        }

        const [messages, meta] = this.afterFetchCallback(
          this.args.channel,
          results
        );

        this.args.channel.messages = messages;
        this.args.channel.details = meta;

        if (this.requestedTargetMessageId) {
          this.scrollToMessage(findArgs["targetMessageId"], {
            highlight: true,
          });
          return;
        }

        if (
          fetchingFromLastRead &&
          messages.length &&
          findArgs["targetMessageId"] !== messages[messages.length - 1].id
        ) {
          this.scrollToMessage(findArgs["targetMessageId"]);
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
        this.loadingMorePast = false;
        this.fillPaneAttempt();
        this.updateLastReadMessage();
      });
  }

  @bind
  fetchMoreMessages({ direction }) {
    const loadingPast = direction === PAST;
    const loadingMoreKey = `loadingMore${capitalize(direction)}`;

    const canLoadMore = loadingPast
      ? this.#messagesManager.canLoadMorePast
      : this.#messagesManager.canLoadMoreFuture;

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
      .messages(this.args.channel.id, findArgs)
      .then((results) => {
        if (
          this._selfDeleted ||
          this.args.channel.id !== results.meta.channel_id ||
          !this.scrollable
        ) {
          return;
        }

        // prevents an edge case where user clicks bottom arrow
        // just after scrolling to top
        if (loadingPast && this.#isAtBottom()) {
          return;
        }

        const [messages, meta] = this.afterFetchCallback(
          this.args.channel,
          results
        );

        if (!messages?.length) {
          return;
        }

        this.args.channel.details = meta;
        this.#messagesManager.addMessages(messages);

        // Edge case for IOS to avoid blank screens
        // and/or scrolling to bottom losing track of scroll position
        if (!loadingPast && (this.capabilities.isIOS || !this.isScrolling)) {
          this.scrollToMessage(messages[0].id, { position: "end" });
        }
      })
      .catch(() => {
        this._handleErrors();
      })
      .finally(() => {
        this[loadingMoreKey] = false;
        this.fillPaneAttempt();
      });
  }

  @debounce(500)
  fillPaneAttempt() {
    if (this._selfDeleted) {
      return;
    }

    // safeguard
    if (this.args.channel.messages?.length > 200) {
      return;
    }

    if (!this.args.channel?.messagesManager?.canLoadMorePast) {
      return;
    }

    const firstMessage = this.args.channel?.messages?.[0];
    if (!firstMessage?.visible) {
      return;
    }

    this.fetchMoreMessages({ direction: PAST });
  }

  @bind
  afterFetchCallback(channel, results) {
    const messages = [];
    let foundFirstNew = false;

    results.chat_messages.forEach((messageData, index) => {
      if (index === 0) {
        messageData.firstOfResults = true;
      }

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
          this.args.channel.currentUserMembership.last_read_message_id &&
        !channel.messages.some((m) => m.newest)
      ) {
        foundFirstNew = true;
        messageData.newest = true;
      }

      messages.push(ChatMessage.create(channel, messageData));
    });

    return [messages, results.meta];
  }

  @debounce(100)
  highlightOrFetchMessage(messageId) {
    const message = this.#messagesManager?.findMessage(messageId);
    if (message) {
      this.scrollToMessage(message.id, {
        highlight: true,
        position: "start",
        autoExpand: true,
      });
      this.requestedTargetMessageId = null;
    } else {
      this.fetchMessages();
    }
  }

  scrollToMessage(
    messageId,
    opts = { highlight: false, position: "start", autoExpand: false }
  ) {
    if (this._selfDeleted) {
      return;
    }

    const message = this.#messagesManager?.findMessage(messageId);
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

  @action
  messageDidEnterViewport(message) {
    message.visible = true;
  }

  @action
  messageDidLeaveViewport(message) {
    message.visible = false;
  }

  @debounce(READ_INTERVAL_MS)
  updateLastReadMessage() {
    schedule("afterRender", () => {
      if (this._selfDeleted) {
        return;
      }

      const lastReadId =
        this.args.channel.currentUserMembership?.last_read_message_id;
      let lastUnreadVisibleMessage = this.args.channel.visibleMessages.findLast(
        (message) => !lastReadId || message.id > lastReadId
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
      if (!this.#isBottomOfMessageVisible(element, this.scrollable)) {
        lastUnreadVisibleMessage = lastUnreadVisibleMessage.previousMessage;

        if (
          !lastUnreadVisibleMessage ||
          lastReadId > lastUnreadVisibleMessage.id
        ) {
          return;
        }
      }

      this.args.channel.updateLastReadMessage(lastUnreadVisibleMessage.id);
    });
  }

  @action
  scrollToLatestMessage() {
    schedule("afterRender", () => {
      if (this._selfDeleted) {
        return;
      }

      if (this.#messagesManager?.canLoadMoreFuture) {
        this._fetchAndScrollToLatest();
      } else if (this.args.channel.messages?.length > 0) {
        this.scrollToMessage(
          this.args.channel.messages[this.args.channel.messages.length - 1].id
        );
      }
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
    cancel(this.onScrollEndedHandler);

    if (!this.scrollable) {
      return;
    }

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
      this.onScrollEndedHandler = discourseLater(this, this.onScrollEnded, 150);
    }
  }

  @bind
  onScrollEnded() {
    this.isScrolling = false;
  }

  removeMessage(msgData) {
    const message = this.#messagesManager.findMessage(msgData.id);
    if (message) {
      this.#messagesManager.removeMessage(message);
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
    if (this.args.channel.isFollowing) {
      this.args.channel.lastMessageSentAt = new Date();
    }

    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      return handleStagedMessage(this.#messagesManager, data);
    }

    if (this.#messagesManager.canLoadMoreFuture) {
      // If we can load more messages, we just notice the user of new messages
      this.hasNewMessages = true;
    } else if (this.#isTowardsBottom()) {
      // If we are at the bottom, we append the message and scroll to it
      const message = ChatMessage.create(this.args.channel, data.chat_message);

      this.#messagesManager.addMessages([message]);
      this.scrollToLatestMessage();
      this.updateLastReadMessage();
    } else {
      // If we are almost at the bottom, we append the message and notice the user
      const message = ChatMessage.create(this.args.channel, data.chat_message);
      this.#messagesManager.addMessages([message]);
      this.hasNewMessages = true;
    }
  }

  // TODO (martin) Maybe change this to public, since its referred to by
  // livePanel.linkedComponent at the moment.
  get _selfDeleted() {
    return this.isDestroying || this.isDestroyed;
  }

  get #messagesManager() {
    return this.args.channel?.messagesManager;
  }

  @action
  sendMessage(message, uploads = []) {
    resetIdle();

    if (this.chatChannelPane.sendingLoading) {
      return;
    }

    this.chatChannelPane.sendingLoading = true;
    this.args.channel.draft = ChatMessageDraft.create();

    // TODO: all send message logic is due for massive refactoring
    // This is all the possible case Im currently aware of
    // - messaging to a public channel where you are not a member yet (preview = true)
    // - messaging to an existing direct channel you were not tracking yet through dm creator (channel draft)
    // - messaging to a new direct channel through DM creator (channel draft)
    // - message to a direct channel you were tracking (preview = false, not draft)
    // - message to a public channel you were tracking (preview = false, not draft)
    // - message to a channel when we haven't loaded all future messages yet.
    if (!this.args.channel.isFollowing || this.args.channel.isDraft) {
      this.loading = true;

      return this._upsertChannelWithMessage(
        this.args.channel,
        message,
        uploads
      ).finally(() => {
        if (this._selfDeleted) {
          return;
        }
        this.loading = false;
        this.chatChannelPane.sendingLoading = false;
        this.chatChannelPane.resetAfterSend();
        this.scrollToLatestMessage();
      });
    }

    const stagedMessage = ChatMessage.createStagedMessage(this.args.channel, {
      message,
      created_at: moment.utc().format(),
      uploads: cloneJSON(uploads),
      user: this.currentUser,
    });

    if (this.chatChannelComposer.replyToMsg) {
      stagedMessage.inReplyTo = this.chatChannelComposer.replyToMsg;
    }

    if (stagedMessage.inReplyTo) {
      if (!this.args.channel.threadingEnabled) {
        this.#messagesManager.addMessages([stagedMessage]);
      }
    } else {
      this.#messagesManager.addMessages([stagedMessage]);
    }

    if (!this.#messagesManager.canLoadMoreFuture) {
      this.scrollToLatestMessage();
    }

    return this.chatApi
      .sendMessage(this.args.channel.id, {
        message: stagedMessage.message,
        in_reply_to_id: stagedMessage.inReplyTo?.id,
        staged_id: stagedMessage.id,
        upload_ids: stagedMessage.uploads.map((upload) => upload.id),
      })
      .then(() => {
        this.scrollToLatestMessage();
      })
      .catch((error) => {
        this._onSendError(stagedMessage.id, error);
        this.scrollToBottom();
      })
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }
        this.chatChannelPane.sendingLoading = false;
        this.chatChannelPane.resetAfterSend();
      });
  }

  async _upsertChannelWithMessage(channel, message, uploads) {
    let promise = Promise.resolve(channel);

    if (channel.isDirectMessageChannel || channel.isDraft) {
      promise = this.chat.upsertDmChannelForUsernames(
        channel.chatable.users.mapBy("username")
      );
    }

    return promise.then((c) =>
      ajax(`/chat/${c.id}.json`, {
        type: "POST",
        data: {
          message,
          upload_ids: (uploads || []).mapBy("id"),
        },
      }).then(() => {
        this.router.transitionTo("chat.channel", "-", c.id);
      })
    );
  }

  _onSendError(id, error) {
    const stagedMessage = this.#messagesManager.findStagedMessage(id);
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

    this.chatChannelPane.resetAfterSend();
  }

  @action
  resendStagedMessage(stagedMessage) {
    this.chatChannelPane.sendingLoading = true;

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
        this.chatChannelPane.sendingLoading = false;
      });
  }

  get chatProgressBarContainer() {
    return document.querySelector("#chat-progress-bar-container");
  }

  @action
  onCloseFullScreen() {
    this.chatStateManager.prefersDrawer();
    this.router.transitionTo(this.chatStateManager.lastKnownAppURL).then(() => {
      this.appEvents.trigger(
        "chat:open-url",
        this.chatStateManager.lastKnownChatURL
      );
    });
  }

  _unsubscribeToUpdates(channelId) {
    if (!channelId) {
      return;
    }

    this.chatChannelPaneSubscriptionsManager.unsubscribe();
    this.messageBus.unsubscribe(`/chat/${channelId}`, this.onMessage);
  }

  _subscribeToUpdates(channel) {
    if (!channel) {
      return;
    }

    this._unsubscribeToUpdates(channel.id);
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
    return this.fetchMessages({
      fetchFromLastMessage: true,
    });
  }

  _handleErrors(error) {
    switch (error?.jqXHR?.status) {
      case 429:
      case 404:
        popupAjaxError(error);
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

    const composer = document.querySelector(".chat-composer-input");
    if (composer && !this.args.channel.isDraft) {
      composer.focus();
      return;
    }

    event.preventDefault();
    event.stopPropagation();
  }

  @action
  computeDatesSeparators() {
    throttle(this, this._computeDatesSeparators, 50, false);
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
    schedule("afterRender", () => {
      if (this._selfDeleted) {
        return;
      }

      if (!this.scrollable) {
        return;
      }

      if (this.capabilities.isIOS) {
        this.scrollable.style.overflow = "hidden";
      }

      callback?.();

      if (this.capabilities.isIOS) {
        discourseLater(() => {
          if (!this.scrollable) {
            return;
          }

          this.scrollable.style.overflow = "auto";
        }, 50);
      }
    });
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
    // - 1.0 to account for rounding errors, especially on firefox
    return rect.bottom - 1.0 <= containerRect.bottom;
  }
}
