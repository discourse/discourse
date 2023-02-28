import { capitalize } from "@ember/string";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import { cloneJSON } from "discourse-common/lib/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatMessageDraft from "discourse/plugins/chat/discourse/models/chat-message-draft";
import Component from "@glimmer/component";
import { bind, debounce } from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import EmberObject, { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cancel, next, schedule, throttle } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import { inject as service } from "@ember/service";
import { Promise } from "rsvp";
import { resetIdle } from "discourse/lib/desktop-notifications";
import {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import { isTesting } from "discourse-common/config/environment";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "discourse-common/lib/get-owner";

const STICKY_SCROLL_LENIENCE = 100;
const PAGE_SIZE = 50;
const SCROLL_HANDLER_THROTTLE_MS = isTesting() ? 0 : 150;
const FETCH_MORE_MESSAGES_DEBOUNCE_MS = isTesting() ? 0 : 500;
const PAST = "past";
const FUTURE = "future";
const READ_INTERVAL_MS = 1000;

export default class ChatLivePane extends Component {
  @service chat;
  @service chatChannelsManager;
  @service router;
  @service chatEmojiPickerManager;
  @service chatComposerPresenceManager;
  @service chatStateManager;
  @service chatApi;
  @service currentUser;
  @service appEvents;
  @service messageBus;
  @service site;

  @tracked loading = false;
  @tracked loadingMorePast = false;
  @tracked loadingMoreFuture = false;
  @tracked hoveredMessageId = null;
  @tracked sendingLoading = false;
  @tracked selectingMessages = false;
  @tracked showChatQuoteSuccess = false;
  @tracked includeHeader = true;
  @tracked editingMessage = null;
  @tracked replyToMsg = null;
  @tracked hasNewMessages = null;
  @tracked isDocked = true;
  @tracked isAlmostDocked = true;

  _loadedChannelId = null;
  _scrollerEl = null;
  _previousScrollTop = null;
  _lastSelectedMessage = null;
  _mentionWarningsSeen = {};
  _unreachableGroupMentions = [];
  _overMembersLimitGroupMentions = [];

  @action
  setupListeners(element) {
    this._scrollerEl = element.querySelector(".chat-messages-scroll");
    this._scrollerEl.addEventListener("scroll", this.onScrollHandler, {
      passive: true,
    });
    window.addEventListener("resize", this.onResizeHandler);
    window.addEventListener("wheel", this.onScrollHandler, {
      passive: true,
    });

    document.addEventListener("scroll", this._forceBodyScroll, {
      passive: true,
    });

    onPresenceChange({
      callback: this.onPresenceChangeCallback,
    });
  }

  @action
  teardownListeners(element) {
    element
      .querySelector(".chat-messages-scroll")
      ?.removeEventListener("scroll", this.onScrollHandler);
    window.removeEventListener("resize", this.onResizeHandler);
    window.removeEventListener("wheel", this.onScrollHandler);
    cancel(this.resizeHandler);
    document.removeEventListener("scroll", this._forceBodyScroll);
    removeOnPresenceChange(this.onPresenceChangeCallback);
  }

  @action
  updateChannel() {
    if (this._loadedChannelId !== this.args.channel?.id) {
      this._unsubscribeToUpdates(this._loadedChannelId);
      this.selectingMessages = false;
      this.cancelEditing();
      this._loadedChannelId = this.args.channel?.id;
    }

    this.loadMessages();
    this._subscribeToUpdates(this.args.channel.id);
  }

  @action
  loadMessages() {
    if (this.args.targetMessageId) {
      this.requestedTargetMessageId = parseInt(this.args.targetMessageId, 10);
    }

    if (this.args.channel?.id) {
      if (this.requestedTargetMessageId) {
        this.highlightOrFetchMessage(this.requestedTargetMessageId);
      } else {
        this.fetchMessages();
      }
    }
  }

  @bind
  onScrollHandler(event) {
    throttle(this, this.onScroll, event, SCROLL_HANDLER_THROTTLE_MS, false);
  }

  @bind
  onResizeHandler() {
    cancel(this.resizeHandler);
    this.resizeHandler = discourseDebounce(
      this,
      this.fillPaneAttempt,
      this.details,
      250
    );
  }

  @bind
  onPresenceChangeCallback(present) {
    if (present) {
      this.updateLastReadMessage();
    }
  }

  get capabilities() {
    return getOwner(this).lookup("capabilities:main");
  }

  @debounce(100)
  fetchMessages(options = {}) {
    if (this._selfDeleted) {
      return;
    }

    this.loadingMorePast = true;
    this.loading = true;
    this.args.channel.clearMessages();

    const findArgs = { pageSize: PAGE_SIZE };
    const fetchingFromLastRead = !options.fetchFromLastMessage;
    if (this.requestedTargetMessageId) {
      findArgs["targetMessageId"] = this.requestedTargetMessageId;
    } else if (fetchingFromLastRead) {
      findArgs["targetMessageId"] = this._getLastReadId();
    }

    return this.chatApi
      .messages(this.args.channel.id, findArgs)
      .then((results) => {
        if (
          this._selfDeleted ||
          this.args.channel.id !== results.meta.channel_id
        ) {
          this.router.transitionTo(
            "chat.channel",
            "-",
            results.meta.channel_id
          );
        }

        const [messages, meta] = this.afterFetchCallback(
          this.args.channel,
          results
        );
        this.args.channel.appendMessages(messages);
        this.args.channel.details = meta;

        if (this.requestedTargetMessageId) {
          this.scrollToMessage(findArgs["targetMessageId"], {
            highlight: true,
          });
        } else if (fetchingFromLastRead) {
          this.scrollToMessage(findArgs["targetMessageId"]);
        } else if (messages.length) {
          this.scrollToMessage(messages.lastObject.id);
        }
      })
      .catch(this._handleErrors)
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }

        this.requestedTargetMessageId = null;
        this.loading = false;
        this.loadingMorePast = false;

        this.fillPaneAttempt();
      });
  }

  @bind
  _fetchMoreMessages({ direction, scrollTo = true }) {
    const loadingPast = direction === PAST;
    const loadingMoreKey = `loadingMore${capitalize(direction)}`;

    const canLoadMore = loadingPast
      ? this.args.channel.canLoadMorePast
      : this.args.channel.canLoadMoreFuture;

    if (!canLoadMore || this.loading || !this.args.channel.messages.length) {
      return Promise.resolve();
    }

    this.loading = true;
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
          this.args.channel.id !== results.meta.channel_id
        ) {
          this.router.transitionTo(
            "chat.channel",
            "-",
            results.meta.channel_id
          );
        }

        const [messages, meta] = this.afterFetchCallback(
          this.args.channel,
          results
        );

        this.loading = false;
        this[loadingMoreKey] = false;

        loadingPast
          ? this.args.channel.prependMessages(messages)
          : this.args.channel.appendMessages(messages);
        this.args.channel.details = meta;

        if (this.args.channel.messages.length && scrollTo) {
          if (loadingPast) {
            this.scrollToMessage(messages[messages.length - 1].id, {
              highlight: false,
              position: "start",
            });
          } else {
            this.scrollToMessage(
              this.args.channel.messages[
                this.args.channel.messages.indexOf(messages[0])
              ].id,
              {
                highlight: false,
                position: "end",
              }
            );
          }
        }

        this.fillPaneAttempt();
      })
      .catch(() => {
        this.loading = false;
        this[loadingMoreKey] = false;
        this._handleErrors();
      });
  }

  fillPaneAttempt() {
    if (this._selfDeleted) {
      return;
    }

    // safeguard
    if (this.args.channel.messages.length > 200) {
      return;
    }

    if (!this.args.channel?.canLoadMorePast) {
      return;
    }

    schedule("afterRender", () => {
      const firstMessageId = this.args.channel?.messages?.[0]?.id;
      if (!firstMessageId) {
        return;
      }

      const scroller = document.querySelector(".chat-messages-container");
      const messageContainer = scroller.querySelector(
        `.chat-message-container[data-id="${firstMessageId}"]`
      );

      if (
        !scroller ||
        !messageContainer ||
        !isElementInViewport(messageContainer)
      ) {
        return;
      }

      this._fetchMoreMessagesThrottled({
        direction: PAST,
        scrollTo: false,
      });
    });
  }

  _fetchMoreMessagesThrottled(params) {
    discourseDebounce(
      this,
      this._fetchMoreMessages,
      params,
      FETCH_MORE_MESSAGES_DEBOUNCE_MS,
      true
    );
  }

  @bind
  afterFetchCallback(channel, results) {
    const messages = [];
    let foundFirstNew = false;

    results.chat_messages.forEach((messageData) => {
      // If a message has been hidden it is because the current user is ignoring
      // the user who sent it, so we want to unconditionally hide it, even if
      // we are going directly to the target
      if (this.currentUser.ignored_users) {
        messageData.hidden = this.currentUser.ignored_users.includes(
          messageData.user.username
        );
      }

      if (this.requestedTargetMessageId === messageData.id) {
        messageData.expanded = !messageData.hidden;
      } else {
        messageData.expanded = !(messageData.hidden || messageData.deleted_at);
      }

      // newest has to be in after fetcg callback as we don't want to make it
      // dynamic or it will make the pane jump around, it will disappear on reload
      if (
        !foundFirstNew &&
        messageData.id > channel.currentUserMembership.last_read_message_id
      ) {
        foundFirstNew = true;
        messageData.newest = true;
      }

      messages.push(ChatMessage.create(channel, messageData));
    });

    return [messages, results.meta];
  }

  _getLastReadId() {
    return this.args.channel.currentUserMembership.last_read_message_id;
  }

  @debounce(100)
  highlightOrFetchMessage(messageId) {
    const message = this.args.channel.findMessage(messageId);
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

    const message = this.args.channel.findMessage(messageId);
    if (message?.deletedAt && opts.autoExpand) {
      message.expanded = true;
    }

    schedule("afterRender", () => {
      const messageEl = this._scrollerEl.querySelector(
        `.chat-message-container[data-id='${messageId}']`
      );

      if (!messageEl || this._selfDeleted) {
        return;
      }

      if (opts.highlight) {
        messageEl.classList.add("highlighted");
        discourseLater(() => {
          messageEl.classList.add("transition-slow");
        }, 2000);
        discourseLater(() => {
          messageEl.classList.remove("highlighted");
          discourseLater(() => {
            messageEl.classList.remove("transition-slow");
          }, 2000);
        }, 3000);
      }

      this._wrapIOSFix(() => {
        messageEl.scrollIntoView({
          block: opts.position ?? "center",
        });
      });
    });
  }

  @action
  didShowMessage(message) {
    message.visible = true;
    this.updateLastReadMessage(message);
    this.#computeSeparators(message);
  }

  @action
  didHideMessage(message) {
    message.visible = false;
  }

  @debounce(READ_INTERVAL_MS)
  updateLastReadMessage() {
    const lastReadId =
      this.args.channel.currentUserMembership?.last_read_message_id;
    const lastUnreadVisibleMessage = this.args.channel.visibleMessages.findLast(
      (message) => !lastReadId || message.id > lastReadId
    );
    if (lastUnreadVisibleMessage) {
      this.args.channel.updateLastReadMessage(lastUnreadVisibleMessage.id);
    }
  }

  @action
  scrollToBottom() {
    next(() => {
      if (this.args.channel.canLoadMoreFuture) {
        this._fetchAndScrollToLatest();
      } else {
        const message =
          this.args.channel.messages[this.args.channel.messages?.length - 1];

        if (message?.id) {
          this.scrollToMessage(message.id, { highlight: false });
          this.hasNewMessages = false;
        }
      }
    });
  }

  onScroll() {
    if (this._selfDeleted) {
      return;
    }

    resetIdle();

    if (this.loading) {
      return;
    }

    const scrollPosition = Math.abs(this._scrollerEl.scrollTop);
    const total = this._scrollerEl.scrollHeight - this._scrollerEl.clientHeight;

    this.isAlmostDocked = scrollPosition / this._scrollerEl.offsetHeight < 0.67;
    this.isDocked = scrollPosition <= 1;

    if (
      this._previousScrollTop - this._scrollerEl.scrollTop >
      this._previousScrollTop
    ) {
      const atTop = this._isBetween(
        scrollPosition,
        total - STICKY_SCROLL_LENIENCE,
        total + STICKY_SCROLL_LENIENCE
      );

      if (atTop) {
        this._fetchMoreMessagesThrottled({ direction: PAST });
      }
    } else {
      const atBottom = this._isBetween(
        scrollPosition,
        0 + STICKY_SCROLL_LENIENCE,
        0 - STICKY_SCROLL_LENIENCE
      );

      if (atBottom) {
        this._fetchMoreMessagesThrottled({ direction: FUTURE });
      }
    }

    this._previousScrollTop = this._scrollerEl.scrollTop;
  }

  _isBetween(target, a, b) {
    const min = Math.min.apply(Math, [a, b]);
    const max = Math.max.apply(Math, [a, b]);
    return target > min && target < max;
  }

  removeMessage(msgData) {
    const message = this.args.channel.findMessage(msgData.id);
    if (message) {
      this.args.channel.removeMessage(message);
    }
  }

  handleMessage(data) {
    switch (data.type) {
      case "sent":
        this.handleSentMessage(data);
        break;
      case "processed":
        this.handleProcessedMessage(data);
        break;
      case "edit":
        this.handleEditMessage(data);
        break;
      case "refresh":
        this.handleRefreshMessage(data);
        break;
      case "delete":
        this.handleDeleteMessage(data);
        break;
      case "bulk_delete":
        this.handleBulkDeleteMessage(data);
        break;
      case "reaction":
        this.handleReactionMessage(data);
        break;
      case "restore":
        this.handleRestoreMessage(data);
        break;
      case "mention_warning":
        this.handleMentionWarning(data);
        break;
      case "self_flagged":
        this.handleSelfFlaggedMessage(data);
        break;
      case "flag":
        this.handleFlaggedMessage(data);
        break;
    }
  }

  _handleOwnSentMessage(data) {
    const stagedMessage = this.args.channel.findStagedMessage(data.staged_id);
    if (stagedMessage) {
      stagedMessage.error = null;
      stagedMessage.id = data.chat_message.id;
      stagedMessage.stagedId = null;
      stagedMessage.excerpt = data.chat_message.excerpt;
      stagedMessage.threadId = data.chat_message.thread_id;
      stagedMessage.channelId = data.chat_message.chat_channel_id;

      const inReplyToMsg = this.args.channel.findMessage(
        data.chat_message.in_reply_to?.id
      );
      if (inReplyToMsg && !inReplyToMsg.threadId) {
        inReplyToMsg.threadId = data.chat_message.thread_id;
      }

      // some markdown is cooked differently on the server-side, e.g.
      // quotes, avatar images etc.
      if (data.chat_message?.cooked !== stagedMessage.cooked) {
        stagedMessage.cooked = data.chat_message.cooked;
      }

      this.appEvents.trigger(
        `chat-message-staged-${data.stagedId}:id-populated`
      );
    }
  }

  handleSentMessage(data) {
    if (this.args.channel.isFollowing) {
      this.args.channel.lastMessageSentAt = new Date();
    }

    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      return this._handleOwnSentMessage(data);
    }

    if (this.args.channel.canLoadMoreFuture) {
      // If we can load more messages, we just notice the user of new messages
      this.hasNewMessages = true;
    } else if (this.isDocked) {
      // If we are at the bottom, we append the message and scroll to it
      const message = ChatMessage.create(this.args.channel, data.chat_message);
      this.args.channel.appendMessages([message]);
      this.scrollToBottom();
    } else {
      // If we are almost at the bottom, we append the message and notice the user
      const message = ChatMessage.create(this.args.channel, data.chat_message);
      this.args.channel.appendMessages([message]);
      this.hasNewMessages = true;
    }
  }

  handleProcessedMessage(data) {
    const message = this.args.channel.findMessage(data.chat_message.id);
    if (message) {
      message.cooked = data.chat_message.cooked;
      this.scrollToBottom();
    }
  }

  handleRefreshMessage(data) {
    const message = this.args.channel.findMessage(data.chat_message.id);
    if (message) {
      message.version = message.version + 1;
    }
  }

  handleEditMessage(data) {
    const message = this.args.channel.findMessage(data.chat_message.id);
    if (message) {
      message.message = data.chat_message.message;
      message.cooked = data.chat_message.cooked;
      message.excerpt = data.chat_message.excerpt;
      message.uploads = cloneJSON(data.chat_message.uploads || []);
      message.edited = true;
    }
  }

  handleBulkDeleteMessage(data) {
    data.deleted_ids.forEach((deletedId) => {
      this.handleDeleteMessage({
        deleted_id: deletedId,
        deleted_at: data.deleted_at,
      });
    });
  }

  handleDeleteMessage(data) {
    const deletedId = data.deleted_id;
    const targetMsg = this.args.channel.findMessage(deletedId);

    if (!targetMsg) {
      return;
    }

    if (this.currentUser.staff || this.currentUser.id === targetMsg.user.id) {
      targetMsg.deletedAt = data.deleted_at;
      targetMsg.expanded = false;
    } else {
      this.args.channel.removeMessage(targetMsg);
    }
  }

  handleReactionMessage(data) {
    if (data.user.id !== this.currentUser.id) {
      const message = this.args.channel.findMessage(data.chat_message_id);
      if (message) {
        message.react(data.emoji, data.action, data.user, this.currentUser.id);
      }
    }
  }

  handleRestoreMessage(data) {
    const message = this.args.channel.findMessage(data.chat_message.id);
    if (message) {
      message.deletedAt = null;
    } else {
      this.args.channel.addMessages([
        ChatMessage.create(this.args.channel, data.chat_message),
      ]);
    }
  }

  handleMentionWarning(data) {
    const message = this.args.channel.findMessage(data.chat_message_id);
    if (message) {
      message.mentionWarning = EmberObject.create(data);
    }
  }

  handleSelfFlaggedMessage(data) {
    const message = this.args.channel.findMessage(data.chat_message_id);
    if (message) {
      message.userFlagStatus = data.user_flag_status;
    }
  }

  handleFlaggedMessage(data) {
    const message = this.args.channel.findMessage(data.chat_message_id);
    if (message) {
      message.reviewableId = data.reviewable_id;
    }
  }

  get _selfDeleted() {
    return this.isDestroying || this.isDestroyed;
  }

  @action
  sendMessage(message, uploads = []) {
    resetIdle();

    if (this.sendingLoading) {
      return;
    }

    this.sendingLoading = true;
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
        this.sendingLoading = false;
        this._resetAfterSend();
        this.scrollToBottom();
      });
    }

    const stagedMessage = ChatMessage.createStagedMessage(this.args.channel, {
      message,
      created_at: new Date(),
      uploads: cloneJSON(uploads),
      user: this.currentUser,
    });

    if (this.replyToMsg) {
      stagedMessage.inReplyTo = this.replyToMsg;
    }

    this.args.channel.appendMessages([stagedMessage]);

    if (!this.args.channel.canLoadMoreFuture) {
      this.scrollToBottom();
    }

    return this.chatApi
      .sendMessage(this.args.channel.id, {
        message: stagedMessage.message,
        in_reply_to_id: stagedMessage.inReplyTo?.id,
        staged_id: stagedMessage.stagedId,
        upload_ids: stagedMessage.uploads.map((upload) => upload.id),
      })
      .then(() => {
        this.scrollToBottom();
      })
      .catch((error) => {
        this._onSendError(stagedMessage.stagedId, error);
      })
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }
        this.sendingLoading = false;
        this._resetAfterSend();
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

  _onSendError(stagedId, error) {
    const stagedMessage = this.args.channel.findStagedMessage(stagedId);
    if (stagedMessage) {
      if (error.jqXHR?.responseJSON?.errors?.length) {
        stagedMessage.error = error.jqXHR.responseJSON.errors[0];
      } else {
        this.chat.markNetworkAsUnreliable();
        stagedMessage.error = "network_error";
      }
    }

    this._resetAfterSend();
  }

  @action
  resendStagedMessage(stagedMessage) {
    this.sendingLoading = true;

    stagedMessage.error = null;

    const data = {
      cooked: stagedMessage.cooked,
      message: stagedMessage.message,
      upload_ids: stagedMessage.uploads.map((upload) => upload.id),
      staged_id: stagedMessage.stagedId,
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
        this.sendingLoading = false;
      });
  }

  @action
  editMessage(chatMessage, newContent, uploads) {
    this.sendingLoading = true;
    let data = {
      new_message: newContent,
      upload_ids: (uploads || []).map((upload) => upload.id),
    };
    return ajax(`/chat/${this.args.channel.id}/edit/${chatMessage.id}`, {
      type: "PUT",
      data,
    })
      .then(() => {
        this._resetAfterSend();
      })
      .catch(popupAjaxError)
      .finally(() => {
        if (this._selfDeleted) {
          return;
        }
        this.sendingLoading = false;
      });
  }

  _resetAfterSend() {
    if (this._selfDeleted) {
      return;
    }

    this.replyToMsg = null;
    this.editingMessage = null;
    this.chatComposerPresenceManager.notifyState(this.args.channel.id, false);
    this.appEvents.trigger("chat-composer:reply-to-set", null);
  }

  @action
  editLastMessageRequested() {
    const lastUserMessage = this.args.channel.messages.find(
      (message) =>
        message.user.id === this.currentUser.id &&
        !message.staged &&
        !message.error
    );

    if (lastUserMessage) {
      this.editingMessage = lastUserMessage;
      this._focusComposer();
    }
  }

  @action
  setReplyTo(messageId) {
    if (messageId) {
      this.cancelEditing();

      const message = this.args.channel.findMessage(messageId);
      this.replyToMsg = message;
      this.appEvents.trigger("chat-composer:reply-to-set", message);
      this._focusComposer();
    } else {
      this.replyToMsg = null;
      this.appEvents.trigger("chat-composer:reply-to-set", null);
    }
  }

  @action
  replyMessageClicked(message) {
    const replyMessageFromLookup = this.args.channel.findMessage(message.id);
    if (replyMessageFromLookup) {
      this.scrollToMessage(replyMessageFromLookup.id, {
        highlight: true,
        position: "start",
        autoExpand: true,
      });
    } else {
      // Message is not present in the loaded messages. Fetch it!
      this.requestedTargetMessageId = message.id;
      this.fetchMessages();
    }
  }

  @action
  editButtonClicked(messageId) {
    const message = this.args.channel.findMessage(messageId);
    this.editingMessage = message;
    this.scrollToBottom();
    this._focusComposer();
  }

  get canInteractWithChat() {
    return !this.args.channel?.userSilenced;
  }

  get chatProgressBarContainer() {
    return document.querySelector("#chat-progress-bar-container");
  }

  get selectedMessageIds() {
    return this.args.channel?.messages
      ?.filter((m) => m.selected)
      ?.map((m) => m.id);
  }

  @action
  onStartSelectingMessages(message) {
    this._lastSelectedMessage = message;
    this.selectingMessages = true;
  }

  @action
  cancelSelecting() {
    this.selectingMessages = false;
    this.args.channel.messages.forEach((message) => {
      message.selected = false;
    });
  }

  @action
  onSelectMessage(message) {
    this._lastSelectedMessage = message;
  }

  @action
  bulkSelectMessages(message, checked) {
    const lastSelectedIndex = this._findIndexOfMessage(
      this._lastSelectedMessage
    );
    const newlySelectedIndex = this._findIndexOfMessage(message);
    const sortedIndices = [lastSelectedIndex, newlySelectedIndex].sort(
      (a, b) => a - b
    );

    for (let i = sortedIndices[0]; i <= sortedIndices[1]; i++) {
      this.args.channel.messages[i].selected = checked;
    }
  }

  _findIndexOfMessage(message) {
    return this.args.channel.messages.findIndex((m) => m.id === message.id);
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

  @action
  cancelEditing() {
    this.editingMessage = null;
  }

  @action
  setInReplyToMsg(inReplyMsg) {
    this.replyToMsg = inReplyMsg;
  }

  @action
  composerValueChanged(value, uploads, replyToMsg) {
    if (!this.editingMessage && !this.args.channel.directMessageChannelDraft) {
      this.args.channel.draft.message = value;
      this.args.channel.draft.uploads = uploads;
      this.args.channel.draft.replyToMsg = replyToMsg;
    }

    if (!this.args.channel.directMessageChannelDraft) {
      this._reportReplyingPresence(value);
    }

    this._persistDraft();
  }

  @debounce(2000)
  _persistDraft() {
    if (!this.args.channel.draft) {
      return;
    }

    ajax("/chat/drafts.json", {
      type: "POST",
      data: {
        chat_channel_id: this.args.channel.id,
        data: this.args.channel.draft.toJSON(),
      },
      ignoreUnsent: false,
    })
      .then(() => {
        this.chat.markNetworkAsReliable();
      })
      .catch((error) => {
        // we ignore a draft which can't be saved because it's too big
        // and only deal with network error for now
        if (!error.jqXHR?.responseJSON?.errors?.length) {
          this.chat.markNetworkAsUnreliable();
        }
      });
  }

  @action
  onHoverMessage(message, options = {}, event) {
    if (this.site.mobileView && options.desktopOnly) {
      return;
    }

    if (message?.staged) {
      return;
    }

    if (
      this.hoveredMessageId &&
      message?.id &&
      this.hoveredMessageId === message?.id
    ) {
      return;
    }

    if (event) {
      if (
        event.type === "mouseleave" &&
        (event.toElement || event.relatedTarget)?.closest(
          ".chat-message-actions-desktop-anchor"
        )
      ) {
        return;
      }

      if (
        event.type === "mouseenter" &&
        (event.fromElement || event.relatedTarget)?.closest(
          ".chat-message-actions-desktop-anchor"
        )
      ) {
        this.hoveredMessageId = message?.id;
        return;
      }
    }

    this._onHoverMessageDebouncedHandler = discourseDebounce(
      this,
      this.debouncedOnHoverMessage,
      message,
      250
    );
  }

  @bind
  debouncedOnHoverMessage(message) {
    if (this._selfDeleted) {
      return;
    }

    this.hoveredMessageId =
      message?.id && message.id !== this.hoveredMessageId ? message.id : null;
  }

  _reportReplyingPresence(composerValue) {
    if (this._selfDeleted) {
      return;
    }

    if (this.args.channel.isDraft) {
      return;
    }

    const replying = !this.editingMessage && !!composerValue;
    this.chatComposerPresenceManager.notifyState(
      this.args.channel.id,
      replying
    );
  }

  _focusComposer() {
    this.appEvents.trigger("chat:focus-composer");
  }

  _unsubscribeToUpdates(channelId) {
    this.messageBus.unsubscribe(`/chat/${channelId}`, this.onMessage);
  }

  _subscribeToUpdates(channelId) {
    this._unsubscribeToUpdates(channelId);
    this.messageBus.subscribe(
      `/chat/${channelId}`,
      this.onMessage,
      this.args.channel.channelMessageBusLastId
    );
  }

  @bind
  onMessage(busData) {
    if (!this.args.channel.canLoadMoreFuture || busData.type !== "sent") {
      this.handleMessage(busData);
    } else if (busData.chat_message.user.id !== this.currentUser.id) {
      this.hasNewMessages = true;
    }
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

  // since -webkit-overflow-scrolling: touch can't be used anymore to disable momentum scrolling
  // we now use this hack to disable it
  @bind
  _wrapIOSFix(callback) {
    if (!this._scrollerEl) {
      return;
    }

    if (this.capabilities.isIOS) {
      this._scrollerEl.style.overflow = "hidden";
    }

    callback();

    if (this.capabilities.isIOS) {
      discourseLater(() => {
        if (!this._scrollerEl) {
          return;
        }

        this._scrollerEl.style.overflow = "auto";
      }, 25);
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
    event.stopPropagation();

    const composer = document.querySelector(".chat-composer-input");
    if (composer && !this.args.channel.isDraft) {
      this.appEvents.trigger("chat:insert-text", key);
      composer.focus();
    }
  }

  #computeSeparators() {
    schedule("afterRender", () => {
      const dates = this._scrollerEl.querySelectorAll(
        ".chat-message-separator-date"
      );
      const scrollHeight = document.querySelector(
        ".chat-messages-scroll"
      ).scrollHeight;

      const reversedDates = [...dates].reverse();
      reversedDates.forEach((date, index) => {
        if (index > 0) {
          date.style.bottom =
            scrollHeight - reversedDates[index - 1].offsetTop + "px";
        } else {
          date.style.bottom = 0;
        }

        date.style.top = date.nextElementSibling.offsetTop + "px";
      });
    });
  }
}
