import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { next, schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import VirtualList from "ember-virtual-scroll-list/components/virtual-list";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { resetIdle } from "discourse/lib/desktop-notifications";
import { NotificationLevels } from "discourse/lib/notification-levels";
import {
  bind,
  debounce as debounceDecorator,
} from "discourse-common/utils/decorators";
import ChatChannelThreadSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-thread-subscription-manager";
import {
  FUTURE,
  PAST,
  READ_INTERVAL_MS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import { bodyScrollFix } from "discourse/plugins/chat/discourse/lib/chat-ios-hacks";
import ChatMessagesLoader from "discourse/plugins/chat/discourse/lib/chat-messages-loader";
import DatesSeparatorsPositioner from "discourse/plugins/chat/discourse/lib/dates-separators-positioner";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";
import ChatComposerThread from "./chat/composer/thread";
import ChatScrollToBottomArrow from "./chat/scroll-to-bottom-arrow";
import ChatSelectionManager from "./chat/selection-manager";
import Message from "./chat-message";
import ChatSkeleton from "./chat-skeleton";
import ChatUploadDropZone from "./chat-upload-drop-zone";

export default class ChatThread extends Component {
  @service capabilities;
  @service chat;
  @service chatApi;
  @service chatDraftsManager;
  @service chatThreadComposer;
  @service chatThreadPane;
  @service currentUser;
  @service router;

  @tracked needsArrow = false;
  @tracked uploadDropZone;
  @tracked atBottom = true;

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
  fetchMessagesByDate(date) {
    if (this.messagesLoader.loading) {
      return;
    }

    const message = this.messagesManager.findFirstMessageOfDay(new Date(date));

    if (
      this.messagesManager.isFirstMessage(message) &&
      this.messagesLoader.canLoadMorePast
    ) {
      this.fetchMessages({ target_date: date, direction: FUTURE });
    } else {
      this.highlightOrFetchMessage(message.id, { position: "top" });
    }
  }

  @debounceDecorator(100)
  highlightOrFetchMessage(messageId, options = {}) {
    const message = this.messagesManager.findMessage(messageId);
    if (message) {
      this.scrollToMessageId(message.id, options);
    } else {
      this.fetchMessages(
        Object.assign({}, { target_message_id: messageId }, options)
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
  }

  @action
  onScroll(state) {
    bodyScrollFix();

    DatesSeparatorsPositioner.apply(this.virtualInstance.root);

    this.needsArrow =
      (this.messagesLoader.fetchedOnce &&
        this.messagesLoader.canLoadMoreFuture) ||
      (state.pxToBottom > 250 && !state.atBottom);
    this.updateLastReadMessage(state.lastVisibleId);

    if (state.atTop) {
      this.fetchMoreMessages({ direction: PAST });
    } else if (state.atBottom) {
      this.fetchMoreMessages({ direction: FUTURE });
      this.atBottom = true;
    }
  }

  @debounceDecorator(READ_INTERVAL_MS)
  updateLastReadMessage() {
    if (!this.args.thread) {
      return;
    }

    return this.chatApi.markThreadAsRead(
      this.args.thread.channel.id,
      this.args.thread.id
    );
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

  async fetchMessages(findArgs = {}) {
    if (this.messagesLoader.loading) {
      return;
    }

    this.messagesLoader.fetchedOnce = false;
    this.messagesManager.clear();

    const result = await this.messagesLoader.load(findArgs);
    this.messagesManager.addMessages(
      this.processMessages(this.args.thread, result)
    );
    this.virtualInstance.refresh();

    if (this.args.targetMessageId) {
      this.scrollToMessageId(this.args.targetMessageId, {
        highlight: findArgs.highlight ?? true,
        position: findArgs.position || "top",
      });
    } else if (this.args.thread.currentUserMembership?.lastReadMessageId) {
      const lastReadMessageId =
        this.args.thread.currentUserMembership?.lastReadMessageId;
      this.scrollToMessageId(lastReadMessageId, { position: "bottom" });
    } else {
      this.scrollToTop();
    }
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

    const messages = this.processMessages(this.args.thread, result);

    if (!messages?.length) {
      return;
    }

    if (direction === PAST) {
      const targetMessageId = this.messagesManager.messages.first.value.id;

      this.messagesManager.addMessages(messages);
      this.virtualInstance.refresh();

      if (this.capabilities.isIOS) {
        this.scrollToMessageId(targetMessageId, { position: "top" });
      }
    } else {
      const targetMessageId = this.virtualInstance.getLastVisibleId();
      this.messagesManager.addMessages(messages);
      this.virtualInstance.refresh();
      this.scrollToMessageId(targetMessageId, { position: "bottom" });
    }
  }

  @action
  scrollToLatestMessage() {
    this.needsArrow = false;
    if (this.messagesLoader.canLoadMoreFuture) {
      this.fetchMessages();
    } else if (this.messagesManager.messages.length > 0) {
      this.virtualInstance.refresh();
      this.scrollToBottom();
    }
  }

  @action
  onTopNotFilled() {
    if (this.messagesLoader.canLoadMorePast) {
      this.fetchMoreMessages({ direction: PAST });
    }
  }

  async scrollToMessageId(messageId, options = {}) {
    const message = await this.virtualInstance?.scrollToId(messageId, options);

    if (options.highlight && message) {
      message.highlight();
    }

    next(() => {
      schedule("afterRender", () => {
        this.updateLastReadMessage(this.virtualInstance.getLastVisibleId());
        bodyScrollFix();
      });
    });
  }

  @bind
  onNewMessage(message) {
    this.messagesManager.addMessages([message]);

    if (this.atBottom) {
      this.scrollToLatestMessage();
    }
  }

  @bind
  processMessages(thread, result) {
    const messages = [];

    result?.messages?.forEach((messageData) => {
      const ignored = this.currentUser.ignored_users || [];
      const hidden = ignored.includes(messageData.user.username);

      const message = ChatMessage.create(thread.channel, {
        ...messageData,
        hidden,
        expanded: !(hidden || messageData.deleted_at),
        manager: this.messagesManager,
        thread,
      });

      messages.push(message);
    });

    thread.details = result.meta;

    return messages;
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

    await this.args.thread.stageMessage(message);

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
  scrollToBottom() {
    this.virtualInstance.scrollToBottom();
    this.needsArrow = false;
  }

  @action
  scrollToTop() {
    this.virtualInstance.scrollToTop();
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

  @action
  registerVirtualInstance(api) {
    this.virtualInstance = api;
  }

  @action
  onRangeChange() {
    DatesSeparatorsPositioner.apply(this.virtualInstance.root);
  }

  @action
  onResize() {
    DatesSeparatorsPositioner.apply(this.virtualInstance.root);
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

      <div
        class="chat-thread__body chat-messages-scroll chat-messages-container popper-viewport"
      >
        <ChatSkeleton @loader={{this.messagesLoader}} />

        <VirtualList
          @onScroll={{this.onScroll}}
          @onResize={{this.onResize}}
          @onRangeChange={{this.onRangeChange}}
          @sources={{this.messagesManager.messages}}
          @registerVirtualInstance={{this.registerVirtualInstance}}
          @onTopNotFilled={{this.onTopNotFilled}}
          @keeps={{300}}
          @estimateSize={{28.5}}
          as |slot firstSlot lastSlot|
        >
          <Message
            @context="thread"
            @message={{slot.source}}
            @firstRenderedMessage={{firstSlot.source}}
            @lastRenderedMessage={{lastSlot.source}}
            @resendStagedMessage={{this.resendStagedMessage}}
            @fetchMessagesByDate={{this.fetchMessagesByDate}}
            {{slot.resizer slot.uniqueKey}}
          />
        </VirtualList>
      </div>

      <ChatScrollToBottomArrow
        @onScrollToBottom={{this.scrollToLatestMessage}}
        @isVisible={{this.needsArrow}}
      />

      {{#if this.chatThreadPane.selectingMessages}}
        <ChatSelectionManager @pane={{this.chatThreadPane}} />
      {{else}}
        <ChatComposerThread
          @channel={{@channel}}
          @thread={{@thread}}
          @onSendMessage={{this.onSendMessage}}
          @uploadDropZone={{this.uploadDropZone}}
        />
      {{/if}}

      <ChatUploadDropZone @model={{@thread}} />
    </div>
  </template>
}
