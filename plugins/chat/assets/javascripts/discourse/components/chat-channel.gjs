import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { and, not } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";
import {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";
import { i18n } from "discourse-i18n";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import firstVisibleMessageId from "discourse/plugins/chat/discourse/helpers/first-visible-message-id";
import ChatChannelSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-subscription-manager";
import {
  FUTURE,
  PAST,
  READ_INTERVAL_MS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatMessagesLoader from "discourse/plugins/chat/discourse/lib/chat-messages-loader";
import { checkMessageTopVisibility } from "discourse/plugins/chat/discourse/lib/check-message-visibility";
import DatesSeparatorsPositioner from "discourse/plugins/chat/discourse/lib/dates-separators-positioner";
import { extractCurrentTopicInfo } from "discourse/plugins/chat/discourse/lib/extract-current-topic-info";
import {
  scrollListToBottom,
  scrollListToMessage,
} from "discourse/plugins/chat/discourse/lib/scroll-helpers";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { stackingContextFix } from "../lib/chat-ios-hacks";
import ChatComposerChannel from "./chat/composer/channel";
import ChatScrollToBottomArrow from "./chat/scroll-to-bottom-arrow";
import ChatSelectionManager from "./chat/selection-manager";
import ChatChannelPreviewCard from "./chat-channel-preview-card";
import ChatMentionWarnings from "./chat-mention-warnings";
import Message from "./chat-message";
import ChatMessagesContainer from "./chat-messages-container";
import ChatMessagesScroller from "./chat-messages-scroller";
import ChatNotices from "./chat-notices";
import ChatSkeleton from "./chat-skeleton";
import ChatUploadDropZone from "./chat-upload-drop-zone";

export default class ChatChannel extends Component {
  @service appEvents;
  @service capabilities;
  @service chat;
  @service chatApi;
  @service chatChannelsManager;
  @service chatDraftsManager;
  @service chatStateManager;
  @service chatChannelScrollPositions;
  @service("chat-channel-composer") composer;
  @service("chat-channel-pane") pane;
  @service currentUser;
  @service dialog;
  @service messageBus;
  @service router;
  @service site;
  @service siteSettings;

  @tracked sending = false;
  @tracked showChatQuoteSuccess = false;
  @tracked includeHeader = true;
  @tracked needsArrow = false;
  @tracked atBottom = true;
  @tracked uploadDropZone;
  @tracked isScrolling = false;

  scroller = null;
  _mentionWarningsSeen = {};
  _unreachableGroupMentions = [];
  _overMembersLimitGroupMentions = [];

  @cached
  get messagesLoader() {
    return new ChatMessagesLoader(getOwner(this), this.args.channel);
  }

  get messagesManager() {
    return this.args.channel.messagesManager;
  }

  get currentUserMembership() {
    return this.args.channel.currentUserMembership;
  }

  get hasSavedScrollPosition() {
    return !!this.chatChannelScrollPositions.get(this.args.channel.id);
  }

  @action
  registerScroller(element) {
    this.scroller = element;
  }

  @action
  teardown() {
    document.removeEventListener("keydown", this._autoFocus);
    this.#cancelHandlers();
    removeOnPresenceChange(this.onPresenceChangeCallback);
    this.subscriptionManager.teardown();
    this.updateLastReadMessage();
  }

  @action
  didResizePane() {
    this.debounceFillPaneAttempt();
    this.debouncedUpdateLastReadMessage();
    DatesSeparatorsPositioner.apply(this.scroller);
  }

  @action
  setup(element) {
    this.uploadDropZone = element;
    document.addEventListener("keydown", this._autoFocus);
    onPresenceChange({ callback: this.onPresenceChangeCallback });

    this.messagesManager.clear();

    if (
      this.args.channel.isDirectMessageChannel &&
      !this.args.channel.isFollowing
    ) {
      this.chatChannelsManager.follow(this.args.channel);
    }

    this.args.channel.draft =
      this.chatDraftsManager.get(this.args.channel?.id) ||
      ChatMessage.createDraftMessage(this.args.channel, {
        user: this.currentUser,
      });

    this.composer.focus();
    this.loadMessages();

    // We update this value server-side when we load the Channel
    // here, so this reflects reality for sidebar unread logic.
    this.args.channel.updateLastViewedAt();
  }

  @action
  loadMessages() {
    if (!this.args.channel?.id) {
      return;
    }

    this.subscriptionManager = new ChatChannelSubscriptionManager(
      this,
      this.args.channel,
      { onNewMessage: this.onNewMessage }
    );

    if (this.args.targetMessageId) {
      this.debounceHighlightOrFetchMessage(this.args.targetMessageId);
    } else if (this.chatChannelScrollPositions.get(this.args.channel.id)) {
      this.debounceHighlightOrFetchMessage(
        this.chatChannelScrollPositions.get(this.args.channel.id)
      );
    } else {
      this.fetchMessages({ fetch_from_last_read: true });
    }
  }

  @bind
  onNewMessage(message) {
    if (!this.atBottom) {
      this.needsArrow = true;
      this.messagesLoader.canLoadMoreFuture = true;
      return;
    }

    stackingContextFix(this.scroller, () => {
      this.messagesManager.addMessages([message]);
    });
    this.debouncedUpdateLastReadMessage();
  }

  @bind
  onPresenceChangeCallback(present) {
    if (present) {
      this.debouncedUpdateLastReadMessage();
    }
  }

  async fetchMessages(findArgs = {}) {
    if (this.messagesLoader.loading) {
      return;
    }

    this.messagesManager.clear();

    const result = await this.messagesLoader.load(findArgs);
    this.messagesManager.messages = this.processMessages(
      this.args.channel,
      result
    );

    if (findArgs.target_message_id) {
      this.scrollToMessageId(findArgs.target_message_id, {
        highlight: true,
        position: findArgs.position,
      });
    } else if (findArgs.fetch_from_last_read) {
      const lastReadMessageId = this.currentUserMembership?.lastReadMessageId;
      this.scrollToMessageId(lastReadMessageId);
    } else if (findArgs.target_date) {
      this.scrollToMessageId(result.meta.target_message_id, {
        highlight: true,
        position: "center",
      });
    } else {
      this._ignoreNextScroll = true;
      this.scrollToBottom();
    }

    this.debounceFillPaneAttempt();
    this.debouncedUpdateLastReadMessage();
  }

  async fetchMoreMessages({ direction }, opts = {}) {
    if (this.messagesLoader.loading) {
      return;
    }

    const result = await this.messagesLoader.loadMore({ direction });
    if (!result) {
      return;
    }

    const messages = this.processMessages(this.args.channel, result);
    if (!messages.length) {
      return;
    }

    const targetMessageId = this.messagesManager.messages.lastObject.id;
    stackingContextFix(this.scroller, () => {
      this.messagesManager.addMessages(messages);
    });

    if (direction === FUTURE && !opts.noScroll) {
      this.scrollToMessageId(targetMessageId, {
        position: "end",
        forceAuto: true,
      });
    }

    this.debounceFillPaneAttempt();
  }

  @action
  async scrollToBottom() {
    this._ignoreNextScroll = true;
    await scrollListToBottom(this.scroller);
    this.debouncedUpdateLastReadMessage();
  }

  scrollToMessageId(messageId, options = {}) {
    this._ignoreNextScroll = true;
    const message = this.messagesManager.findMessage(messageId);
    scrollListToMessage(this.scroller, message, options);
  }

  debounceFillPaneAttempt() {
    this._debouncedFillPaneAttemptHandler = discourseDebounce(
      this,
      this.fillPaneAttempt,
      500
    );
  }

  @bind
  fetchMessagesByDate(date) {
    if (this.messagesLoader.loading) {
      return;
    }

    const message = this.messagesManager.findFirstMessageOfDay(new Date(date));
    if (message.firstOfResults && this.messagesLoader.canLoadMorePast) {
      this.fetchMessages({ target_date: date, direction: FUTURE });
    } else {
      this.highlightOrFetchMessage(message.id, { position: "center" });
    }
  }

  async fillPaneAttempt() {
    if (!this.messagesLoader.fetchedOnce) {
      return;
    }

    // safeguard
    if (this.messagesManager.messages.length > 200) {
      return;
    }

    if (!this.messagesLoader.canLoadMorePast) {
      return;
    }

    schedule("afterRender", () => {
      const firstMessageId = this.messagesManager.messages.firstObject?.id;
      const messageContainer = this.scroller.querySelector(
        `.chat-message-container[data-id="${firstMessageId}"]`
      );
      if (
        messageContainer &&
        checkMessageTopVisibility(this.scroller, messageContainer)
      ) {
        this.fetchMoreMessages({ direction: PAST });
      }
    });
  }

  @bind
  processMessages(channel, result) {
    const messages = [];
    let foundFirstNew = false;
    const hasNewest = this.messagesManager.messages.some((m) => m.newest);

    result?.messages?.forEach((messageData, index) => {
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
        !hasNewest &&
        !foundFirstNew &&
        messageData.id > this.currentUserMembership?.lastReadMessageId
      ) {
        foundFirstNew = true;
        messageData.newest = true;
      }

      const message = ChatMessage.create(channel, messageData);
      message.manager = channel.messagesManager;

      if (message.thread) {
        this.#preloadThreadTrackingState(
          message.thread,
          result.tracking.thread_tracking
        );
      }

      messages.push(message);
    });

    return messages;
  }

  debounceHighlightOrFetchMessage(messageId, options = {}) {
    this._debouncedHighlightOrFetchMessageHandler = discourseDebounce(
      this,
      this.highlightOrFetchMessage,
      messageId,
      options,
      100
    );
  }

  highlightOrFetchMessage(messageId, options = {}) {
    const message = this.messagesManager.findMessage(messageId);
    if (message) {
      this.scrollToMessageId(
        message.id,
        Object.assign(
          {
            highlight: true,
            position: "start",
            autoExpand: true,
            behavior: this.capabilities.isIOS ? "smooth" : null,
          },
          options
        )
      );
    } else {
      this.fetchMessages({ target_message_id: messageId, position: "end" });
    }
  }

  debouncedUpdateLastReadMessage() {
    this._debouncedUpdateLastReadMessageHandler = discourseDebounce(
      this,
      this.updateLastReadMessage,
      READ_INTERVAL_MS
    );
  }

  updateLastReadMessage() {
    if (!this.args.channel.isFollowing) {
      return;
    }

    const firstFullyVisibleMessageId = firstVisibleMessageId(this.scroller);
    if (!firstFullyVisibleMessageId) {
      return;
    }

    let firstMessage = this.messagesManager.findMessage(
      firstFullyVisibleMessageId
    );
    if (!firstMessage) {
      return;
    }

    const lastReadId =
      this.args.channel.currentUserMembership?.lastReadMessageId;
    if (lastReadId >= firstMessage.id) {
      return;
    }

    return this.chatApi.markChannelAsRead(
      this.args.channel.id,
      firstMessage.id
    );
  }

  @action
  scrollToLatestMessage() {
    if (this.messagesLoader.canLoadMoreFuture) {
      this.fetchMessages();
    } else if (this.messagesManager.messages.length > 0) {
      this.scrollToBottom(this.scroller);
    }
  }

  @action
  onScroll(state) {
    next(() => {
      if (this.#flushIgnoreNextScroll()) {
        return;
      }

      DatesSeparatorsPositioner.apply(this.scroller);

      this.needsArrow =
        (this.messagesLoader.fetchedOnce &&
          this.messagesLoader.canLoadMoreFuture) ||
        (state.distanceToBottom.pixels > 250 && !state.atBottom);
      this.isScrolling = true;
      this.debouncedUpdateLastReadMessage();

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
    this.atBottom = state.atBottom;

    if (state.atBottom) {
      this.fetchMoreMessages({ direction: FUTURE });
      this.chatChannelScrollPositions.delete(this.args.channel.id);
    } else {
      this.chatChannelScrollPositions.set(
        this.args.channel.id,
        state.firstVisibleId
      );
    }
  }

  @action
  async onSendMessage(message) {
    if (
      message.message.length > this.siteSettings.chat_maximum_message_length
    ) {
      this.dialog.alert(
        i18n("chat.message_too_long", {
          count: this.siteSettings.chat_maximum_message_length,
        })
      );
      return;
    }

    await message.cook();
    if (message.editing) {
      await this.#sendEditMessage(message);
    } else {
      await this.#sendNewMessage(message);
    }
  }

  @action
  resetComposerMessage() {
    this.args.channel.resetDraft(this.currentUser);
  }

  async #sendEditMessage(message) {
    this.pane.sending = true;

    const data = {
      message: message.message,
      upload_ids: message.uploads.map((upload) => upload.id),
    };

    this.resetComposerMessage();

    try {
      stackingContextFix(this.scroller, async () => {
        await this.chatApi.editMessage(this.args.channel.id, message.id, data);
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      message.editing = false;
      this.pane.sending = false;
    }
  }

  async #sendNewMessage(message) {
    this.pane.sending = true;

    stackingContextFix(this.scroller, async () => {
      await this.args.channel.stageMessage(message);
    });

    message.manager = this.args.channel.messagesManager;
    this.resetComposerMessage();

    if (!this.capabilities.isIOS && !this.messagesLoader.canLoadMoreFuture) {
      this.scrollToLatestMessage();
    }

    try {
      await this.chatApi.sendMessage(this.args.channel.id, {
        message: message.message,
        in_reply_to_id: message.inReplyTo?.id,
        staged_id: message.id,
        upload_ids: message.uploads.map((upload) => upload.id),
        ...extractCurrentTopicInfo(this),
      });

      if (!this.capabilities.isIOS) {
        this.scrollToLatestMessage();
      }
    } catch (error) {
      this._onSendError(message.id, error);
    } finally {
      this.pane.sending = false;
    }
  }

  _onSendError(id, error) {
    const stagedMessage =
      this.args.channel.messagesManager.findStagedMessage(id);
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
        this.pane.sending = false;
      });
  }

  @action
  onCloseFullScreen() {
    this.chatStateManager.prefersDrawer();

    DiscourseURL.routeTo(this.chatStateManager.lastKnownAppURL).then(() => {
      DiscourseURL.routeTo(this.chatStateManager.lastKnownChatURL);
    });
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

  #cancelHandlers() {
    cancel(this._debouncedHighlightOrFetchMessageHandler);
    cancel(this._debouncedUpdateLastReadMessageHandler);
    cancel(this._debouncedFillPaneAttemptHandler);
  }

  #preloadThreadTrackingState(thread, threadTracking) {
    if (!threadTracking[thread.id]) {
      return;
    }

    thread.tracking.unreadCount = threadTracking[thread.id].unread_count;
    thread.tracking.mentionCount = threadTracking[thread.id].mention_count;
    thread.tracking.watchedThreadsUnreadCount =
      threadTracking[thread.id].watched_threads_unread_count;
  }

  #flushIgnoreNextScroll() {
    const prev = this._ignoreNextScroll;
    this._ignoreNextScroll = false;
    return prev;
  }

  <template>
    <div
      class={{concatClass
        "chat-channel"
        (if this.messagesLoader.loading "loading")
        (if this.pane.sending "chat-channel--sending")
        (if this.hasSavedScrollPosition "chat-channel--saved-scroll-position")
        (unless this.messagesLoader.fetchedOnce "chat-channel--not-loaded-once")
      }}
      {{willDestroy this.teardown}}
      {{didInsert this.setup}}
      {{didUpdate this.loadMessages @targetMessageId}}
      data-id={{@channel.id}}
    >
      <ChatChannelStatus @channel={{@channel}} />
      <ChatNotices @channel={{@channel}} />
      <ChatMentionWarnings />

      <ChatMessagesScroller
        @onRegisterScroller={{this.registerScroller}}
        @onScroll={{this.onScroll}}
        @onScrollEnd={{this.onScrollEnd}}
      >
        <ChatMessagesContainer @didResizePane={{this.didResizePane}}>
          {{#each this.messagesManager.messages key="id" as |message|}}
            <Message
              @message={{message}}
              @disableMouseEvents={{this.isScrolling}}
              @resendStagedMessage={{this.resendStagedMessage}}
              @fetchMessagesByDate={{this.fetchMessagesByDate}}
              @context="channel"
            />
          {{else}}
            {{#unless this.messagesLoader.fetchedOnce}}
              <ChatSkeleton />
            {{/unless}}
          {{/each}}
        </ChatMessagesContainer>

        {{! at bottom even if shown at top due to column-reverse  }}
        {{#if this.messagesLoader.loadedPast}}
          <div class="all-loaded-message">
            {{i18n "chat.all_loaded"}}
          </div>
        {{/if}}
      </ChatMessagesScroller>

      <ChatScrollToBottomArrow
        @onScrollToBottom={{this.scrollToLatestMessage}}
        @isVisible={{this.needsArrow}}
      />

      {{#if this.pane.selectingMessages}}
        <ChatSelectionManager
          @enableMove={{and
            (not @channel.isDirectMessageChannel)
            @channel.canModerate
          }}
          @pane={{this.pane}}
          @messagesManager={{this.messagesManager}}
        />
      {{else}}
        {{#if (and (not @channel.isFollowing) @channel.isCategoryChannel)}}
          <ChatChannelPreviewCard @channel={{@channel}} />
        {{else}}
          <ChatComposerChannel
            @channel={{@channel}}
            @uploadDropZone={{this.uploadDropZone}}
            @onSendMessage={{this.onSendMessage}}
            @scroller={{this.scroller}}
          />
        {{/if}}
      {{/if}}

      <ChatUploadDropZone @model={{@channel}} />
    </div>
  </template>
}
