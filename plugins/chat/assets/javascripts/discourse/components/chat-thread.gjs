import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { NotificationLevels } from "discourse/lib/notification-levels";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import ChatThreadTitlePrompt from "discourse/plugins/chat/discourse/components/chat-thread-title-prompt";
import firstVisibleMessageId from "discourse/plugins/chat/discourse/helpers/first-visible-message-id";
import ChatChannelThreadSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-thread-subscription-manager";
import {
  FUTURE,
  PAST,
  READ_INTERVAL_MS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import { stackingContextFix } from "discourse/plugins/chat/discourse/lib/chat-ios-hacks";
import ChatMessagesLoader from "discourse/plugins/chat/discourse/lib/chat-messages-loader";
import DatesSeparatorsPositioner from "discourse/plugins/chat/discourse/lib/dates-separators-positioner";
import { extractCurrentTopicInfo } from "discourse/plugins/chat/discourse/lib/extract-current-topic-info";
import {
  scrollListToBottom,
  scrollListToMessage,
  scrollListToTop,
} from "discourse/plugins/chat/discourse/lib/scroll-helpers";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";
import ChatComposerThread from "./chat/composer/thread";
import ChatScrollToBottomArrow from "./chat/scroll-to-bottom-arrow";
import ChatSelectionManager from "./chat/selection-manager";
import Message from "./chat-message";
import ChatMessagesContainer from "./chat-messages-container";
import ChatMessagesScroller from "./chat-messages-scroller";
import ChatSkeleton from "./chat-skeleton";
import ChatThreadHeading from "./chat-thread-heading";
import ChatUploadDropZone from "./chat-upload-drop-zone";

export default class ChatThread extends Component {
  @service appEvents;
  @service capabilities;
  @service chat;
  @service chatApi;
  @service chatHistory;
  @service chatDraftsManager;
  @service chatThreadComposer;
  @service chatThreadPane;
  @service dialog;
  @service currentUser;
  @service router;
  @service siteSettings;

  @tracked atBottom = true;
  @tracked isScrolling = false;
  @tracked needsArrow = false;
  @tracked uploadDropZone;

  scroller = null;

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
  setup(element) {
    this.uploadDropZone = element;

    this.messagesManager.clear();
    this.args.thread.draft =
      this.chatDraftsManager.get(
        this.args.thread.channel?.id,
        this.args.thread.id
      ) ||
      ChatMessage.createDraftMessage(this.args.thread.channel, {
        user: this.currentUser,
        thread: this.args.thread,
      });
    this.chatThreadComposer.focus();
    this.loadMessages();
  }

  @action
  teardown() {
    this.subscriptionManager.teardown();
    cancel(this._debouncedFillPaneAttemptHandler);
    cancel(this._debounceUpdateLastReadMessageHandler);
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
    if (!this.args.thread?.currentUserMembership) {
      return;
    }

    const firstFullyVisibleMessageId = firstVisibleMessageId(this.scroller);
    if (!firstFullyVisibleMessageId) {
      return;
    }

    const firstMessage = this.messagesManager.findMessage(
      firstFullyVisibleMessageId
    );
    if (!firstMessage) {
      return;
    }

    const lastReadId = this.args.thread.currentUserMembership.lastReadMessageId;
    if (lastReadId >= firstMessage.id) {
      return;
    }

    return this.chatApi.markThreadAsRead(
      this.args.thread.channel.id,
      this.args.thread.id,
      firstMessage.id
    );
  }

  @action
  registerScroller(element) {
    this.scroller = element;
  }

  @action
  loadMessages() {
    this.fetchMessages();
    this.subscriptionManager = new ChatChannelThreadSubscriptionManager(
      this,
      this.args.thread,
      { onNewMessage: this.onNewMessage }
    );
  }

  @action
  didResizePane() {
    this._ignoreNextScroll = true;
    this.debounceFillPaneAttempt();
    this.debounceUpdateLastReadMessage();
    DatesSeparatorsPositioner.apply(this.scroller);
  }

  async fetchMessages(findArgs = {}) {
    if (this.messagesLoader.loading) {
      return;
    }

    this.messagesManager.clear();

    findArgs.target_message_id ??=
      findArgs.targetMessageId ||
      this.args.targetMessageId ||
      this.args.thread.currentUserMembership?.lastReadMessageId;

    if (!findArgs.target_message_id) {
      findArgs.direction = FUTURE;
    }

    const result = await this.messagesLoader.load(findArgs);
    if (!result) {
      return;
    }

    const [messages, meta] = this.processMessages(this.args.thread, result);
    stackingContextFix(this.scroller, () => {
      this.messagesManager.addMessages(messages);
    });
    this.args.thread.details = meta;

    if (meta.target_message_id) {
      this.scrollToMessageId(meta.target_message_id, { highlight: true });
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

    stackingContextFix(this.scroller, () => {
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
    scrollListToMessage(this.scroller, message, opts);
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

  @action
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
      this.fetchMessages({ target_message_id: messageId });
    }
  }

  @action
  resetComposerMessage() {
    this.args.thread.draft = ChatMessage.createDraftMessage(
      this.args.thread.channel,
      {
        user: this.currentUser,
        thread: this.args.thread,
      }
    );
  }

  async #sendNewMessage(message) {
    if (this.chatThreadPane.sending) {
      return;
    }

    this.chatThreadPane.sending = true;
    this._ignoreNextScroll = true;
    stackingContextFix(this.scroller, async () => {
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
          in_reply_to_id: null,
          staged_id: message.id,
          upload_ids: message.uploads.map((upload) => upload.id),
          thread_id: message.thread.id,
          ...extractCurrentTopicInfo(this),
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
      this.chatDraftsManager.remove(
        this.args.thread.channel.id,
        this.args.thread.id
      );
      this.chatThreadPane.sending = false;
    }
  }

  async #sendEditMessage(message) {
    this.chatThreadPane.sending = true;

    const data = {
      message: message.message,
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
      this.chatDraftsManager.remove(
        this.args.thread.channel.id,
        this.args.thread.id
      );
      this.chatThreadPane.sending = false;
    }
  }

  @action
  async scrollToBottom() {
    this._ignoreNextScroll = true;
    await scrollListToBottom(this.scroller);
  }

  @action
  async scrollToTop() {
    this._ignoreNextScroll = true;
    await scrollListToTop(this.scroller);
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

  <template>
    <div
      class={{concatClass
        "chat-thread"
        (if this.messagesLoader.loading "loading")
      }}
      data-id={{@thread.id}}
      {{didInsert this.setup}}
      {{willDestroy this.teardown}}
    >
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
              @context="thread"
            />
          {{/each}}

          {{#unless this.messagesLoader.fetchedOnce}}
            {{#if this.messagesLoader.loading}}
              <ChatSkeleton />
            {{/if}}
          {{/unless}}
        </ChatMessagesContainer>

        <ChatThreadHeading @thread={{@thread}} />
      </ChatMessagesScroller>

      <ChatScrollToBottomArrow
        @onScrollToBottom={{this.scrollToLatestMessage}}
        @isVisible={{this.needsArrow}}
      />

      {{#if this.chatThreadPane.selectingMessages}}
        <ChatSelectionManager
          @pane={{this.chatThreadPane}}
          @messagesManager={{this.messagesManager}}
        />
      {{else}}
        <ChatComposerThread
          @channel={{@channel}}
          @thread={{@thread}}
          @onSendMessage={{this.onSendMessage}}
          @uploadDropZone={{this.uploadDropZone}}
          @scroller={{this.scroller}}
        />
      {{/if}}

      <ChatUploadDropZone @model={{@thread}} />
      <ChatThreadTitlePrompt @thread={{@thread}} />
    </div>
  </template>
}
