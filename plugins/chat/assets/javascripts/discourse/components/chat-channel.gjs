import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { next, schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import VirtualList from "ember-virtual-scroll-list/components/virtual-list";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { resetIdle } from "discourse/lib/desktop-notifications";
import DiscourseURL from "discourse/lib/url";
import userPresent, {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";
import {
  bind,
  debounce as debounceDecorator,
} from "discourse-common/utils/decorators";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import Message from "discourse/plugins/chat/discourse/components/chat-message";
import ChatChannelSubscriptionManager from "discourse/plugins/chat/discourse/lib/chat-channel-subscription-manager";
import {
  FUTURE,
  PAST,
  READ_INTERVAL_MS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";
import { bodyScrollFix } from "discourse/plugins/chat/discourse/lib/chat-ios-hacks";
import ChatMessagesLoader from "discourse/plugins/chat/discourse/lib/chat-messages-loader";
import DatesSeparatorsPositioner from "discourse/plugins/chat/discourse/lib/dates-separators-positioner";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatComposerChannel from "./chat/composer/channel";
import ChatScrollToBottomArrow from "./chat/scroll-to-bottom-arrow";
import ChatSelectionManager from "./chat/selection-manager";
import ChatAllLoaded from "./chat-all-loaded";
import ChatChannelPreviewCard from "./chat-channel-preview-card";
import ChatMentionWarnings from "./chat-mention-warnings";
import ChatNotices from "./chat-notices";
import ChatSkeleton from "./chat-skeleton";
import ChatUploadDropZone from "./chat-upload-drop-zone";

export default class ChatChannel extends Component {
  @service capabilities;
  @service chat;
  @service chatApi;
  @service chatChannelsManager;
  @service chatComposerPresenceManager;
  @service chatDraftsManager;
  @service chatStateManager;
  @service("chat-channel-composer") composer;
  @service("chat-channel-pane") pane;
  @service currentUser;
  @service site;
  @service chatChannelScrollPositions;

  @tracked sending = false;
  @tracked showChatQuoteSuccess = false;
  @tracked includeHeader = true;
  @tracked needsArrow = false;
  @tracked atBottom = true;
  @tracked uploadDropZone;
  @tracked scrolling = false;

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

  @action
  teardown() {
    document.removeEventListener("keydown", this._autoFocus);
    removeOnPresenceChange(this.onPresenceChangeCallback);
    this.subscriptionManager.teardown();
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
      this.highlightOrFetchMessage(this.args.targetMessageId);
    } else if (this.chatChannelScrollPositions.get(this.args.channel.id)) {
      this.fetchMessages({
        target_message_id: this.chatChannelScrollPositions.get(
          this.args.channel.id
        ),
        highlight: false,
        position: "bottom",
      });
    } else {
      this.fetchMessages({
        fetch_from_last_read: true,
        position: "top",
      });
    }
  }

  @bind
  onNewMessage(message) {
    this.messagesManager.addMessages([message]);

    if (this.atBottom) {
      if (userPresent()) {
        this.scrollToLatestMessage();
      } else {
        this.needsArrow = true;
      }
    }
  }

  @bind
  onPresenceChangeCallback(present) {
    if (present) {
      this.updateLastReadMessage(this.virtualInstance.getLastVisibleId());

      bodyScrollFix(true);
    }
  }

  async fetchMessages(findArgs = {}) {
    if (this.messagesLoader.loading) {
      return;
    }

    this.messagesLoader.fetchedOnce = false;
    this.messagesManager.clear();

    const result = await this.messagesLoader.load(findArgs);
    this.messagesManager.addMessages(
      this.processMessages(this.args.channel, result)
    );
    this.virtualInstance.refresh();

    if (findArgs.target_message_id) {
      this.scrollToMessageId(
        findArgs.target_message_id,
        Object.assign(
          {
            highlight: true,
            position: "top",
          },
          findArgs
        )
      );
    } else if (findArgs.fetch_from_last_read) {
      const lastReadMessageId = this.currentUserMembership?.lastReadMessageId;
      this.scrollToMessageId(
        lastReadMessageId,
        Object.assign(
          {
            position: "bottom",
          },
          findArgs
        )
      );
    } else if (findArgs.target_date) {
      this.scrollToMessageId(
        result.meta.target_message_id,
        Object.assign(
          {
            highlight: true,
          },
          findArgs
        )
      );
    } else {
      this.scrollToBottom();
    }

    this.virtualInstance.refreshScrollState();
  }

  async fetchMoreMessages({ direction }) {
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
  scrollToBottom() {
    this.virtualInstance?.scrollToBottom();

    next(() => {
      schedule("afterRender", () => {
        this.updateLastReadMessage(this.virtualInstance.getLastVisibleId());
        this.needsArrow = false;
      });
    });
  }

  async scrollToMessageId(messageId, options = {}) {
    if (!messageId) {
      this.scrollToBottom();
      return;
    }

    const message = await this.virtualInstance?.scrollToId(messageId, options);

    if (options.highlight && message) {
      message.highlight();
    }

    next(() => {
      schedule("afterRender", () => {
        this.updateLastReadMessage(this.virtualInstance.getLastVisibleId());
        this.needsArrow = messageId !== this.virtualInstance.getLastVisibleId();
      });
    });
    bodyScrollFix();
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

  @bind
  processMessages(channel, result) {
    const messages = [];
    let foundFirstNew = false;
    const hasNewest = this.messagesManager.messages.some(
      (node) => node.value.newest
    );

    result?.messages?.forEach((messageData) => {
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

  @debounceDecorator(100)
  highlightOrFetchMessage(messageId, options = {}) {
    const message = this.messagesManager.findMessage(messageId);
    if (message) {
      this.scrollToMessageId(
        message.id,
        Object.assign({ highlight: true }, options)
      );
    } else {
      this.fetchMessages(
        Object.assign({}, { target_message_id: messageId }, options)
      );
    }
  }

  @debounceDecorator(READ_INTERVAL_MS)
  updateLastReadMessage(id) {
    if (!this.args.channel.isFollowing) {
      return;
    }

    if (!id || id < this.currentUserMembership?.lastReadMessageId) {
      return;
    }

    return this.chatApi.markChannelAsRead(this.args.channel.id, id);
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

  @bind
  onScroll(state) {
    bodyScrollFix();

    this.scrolling = true;

    DatesSeparatorsPositioner.apply(this.virtualInstance.root);
    this.needsArrow =
      (this.messagesLoader.fetchedOnce &&
        this.messagesLoader.canLoadMoreFuture) ||
      (state.pxToBottom > 250 && !state.atBottom);
    this.updateLastReadMessage(state.lastVisibleId);

    if (state.atBottom) {
      this.chatChannelScrollPositions.set(this.args.channel.id, null);
    } else {
      this.chatChannelScrollPositions.set(
        this.args.channel.id,
        this.virtualInstance?.getLastVisibleId()
      );
    }

    if (state.atTop) {
      this.fetchMoreMessages({ direction: PAST });
    } else if (state.atBottom) {
      this.atBottom = true;
      this.fetchMoreMessages({ direction: FUTURE });
    }
  }

  @action
  onScrollEnded() {
    this.scrolling = false;
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
      await this.chatApi.editMessage(this.args.channel.id, message.id, data);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      message.editing = false;
      this.pane.sending = false;
    }
  }

  async #sendNewMessage(message) {
    this.pane.sending = true;

    resetIdle();

    await this.args.channel.stageMessage(message);

    this.resetComposerMessage();

    if (!this.messagesLoader.canLoadMoreFuture) {
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

  #preloadThreadTrackingState(thread, threadTracking) {
    if (!threadTracking[thread.id]) {
      return;
    }

    thread.tracking.unreadCount = threadTracking[thread.id].unread_count;
    thread.tracking.mentionCount = threadTracking[thread.id].mention_count;
  }

  @action
  registerVirtualInstance(instance) {
    this.virtualInstance = instance;
  }

  @action
  onRangeChange() {
    DatesSeparatorsPositioner.apply(this.virtualInstance.root);
  }

  @action
  onResize() {
    DatesSeparatorsPositioner.apply(this.virtualInstance.root);
  }

  @action
  onTopNotFilled() {
    if (this.messagesLoader.canLoadMorePast) {
      this.fetchMoreMessages({ direction: PAST });
    }
  }

  <template>
    <div
      class={{concatClass
        "chat-channel"
        (if this.messagesLoader.loading "loading")
        (if this.pane.sending "chat-channel--sending")
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

      <div class="chat-messages-scroll chat-messages-container popper-viewport">
        <ChatSkeleton @loader={{this.messagesLoader}} />

        <VirtualList
          @onScroll={{this.onScroll}}
          @onResize={{this.onResize}}
          @onScrollEnded={{this.onScrollEnded}}
          @onRangeChange={{this.onRangeChange}}
          @onTopNotFilled={{this.onTopNotFilled}}
          @canLoadMoreBottom={{this.messagesLoader.canLoadMoreFuture}}
          @sources={{this.messagesManager.messages}}
          @registerVirtualInstance={{this.registerVirtualInstance}}
          @keeps={{300}}
          @estimateSize={{28.5}}
          as |slot firstSlot lastSlot|
        >
          <Message
            @context="channel"
            @disableMouseEvents={{this.scrolling}}
            @message={{slot.source}}
            @firstRenderedMessage={{firstSlot.source}}
            @lastRenderedMessage={{lastSlot.source}}
            @resendStagedMessage={{this.resendStagedMessage}}
            @fetchMessagesByDate={{this.fetchMessagesByDate}}
            {{slot.resizer slot.uniqueKey}}
          />
        </VirtualList>

        {{#if this.messagesLoader.loadedPast}}
          <ChatAllLoaded />
        {{/if}}
      </div>

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
        />
      {{else}}
        {{#if (and (not @channel.isFollowing) @channel.isCategoryChannel)}}
          <ChatChannelPreviewCard @channel={{@channel}} />
        {{else}}
          <ChatComposerChannel
            @channel={{@channel}}
            @uploadDropZone={{this.uploadDropZone}}
            @onSendMessage={{this.onSendMessage}}
          />
        {{/if}}
      {{/if}}

      <ChatUploadDropZone @model={{@channel}} />
    </div>
  </template>
}
