import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq, lt, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import { updateUserStatusOnMention } from "discourse/lib/update-user-status-on-mention";
import isZoomed from "discourse/lib/zoom-check";
import discourseDebounce from "discourse-common/lib/debounce";
import getURL from "discourse-common/lib/get-url";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import ChatMessageAvatar from "discourse/plugins/chat/discourse/components/chat/message/avatar";
import ChatMessageError from "discourse/plugins/chat/discourse/components/chat/message/error";
import ChatMessageInfo from "discourse/plugins/chat/discourse/components/chat/message/info";
import ChatMessageLeftGutter from "discourse/plugins/chat/discourse/components/chat/message/left-gutter";
import ChatMessageActionsMobileModal from "discourse/plugins/chat/discourse/components/chat-message-actions-mobile";
import ChatMessageInReplyToIndicator from "discourse/plugins/chat/discourse/components/chat-message-in-reply-to-indicator";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import ChatMessageSeparator from "discourse/plugins/chat/discourse/components/chat-message-separator";
import ChatMessageText from "discourse/plugins/chat/discourse/components/chat-message-text";
import ChatMessageThreadIndicator from "discourse/plugins/chat/discourse/components/chat-message-thread-indicator";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import ChatOnLongPress from "discourse/plugins/chat/discourse/modifiers/chat/on-long-press";

let _chatMessageDecorators = [];

export function addChatMessageDecorator(decorator) {
  _chatMessageDecorators.push(decorator);
}

export function resetChatMessageDecorators() {
  _chatMessageDecorators = [];
}

export const MENTION_KEYWORDS = ["here", "all"];
export const MESSAGE_CONTEXT_THREAD = "thread";

export default class ChatMessage extends Component {
  @service site;
  @service dialog;
  @service currentUser;
  @service appEvents;
  @service capabilities;
  @service chat;
  @service chatApi;
  @service chatEmojiReactionStore;
  @service chatEmojiPickerManager;
  @service chatChannelPane;
  @service chatThreadPane;
  @service chatChannelsManager;
  @service router;
  @service toasts;
  @service modal;

  @tracked isActive = false;

  toggleCheckIfPossible = modifier((element) => {
    let addedListener = false;

    const handler = () => {
      if (!this.pane.selectingMessages) {
        return;
      }

      if (event.shiftKey) {
        this.messageInteractor.bulkSelect(!this.args.message.selected);
        return;
      }

      this.messageInteractor.select(!this.args.message.selected);
    };

    if (this.pane.selectingMessages) {
      element.addEventListener("click", handler, { passive: true });
      addedListener = true;
    }

    return () => {
      if (addedListener) {
        element.removeEventListener("click", handler);
      }
    };
  });

  get pane() {
    return this.threadContext ? this.chatThreadPane : this.chatChannelPane;
  }

  get messageInteractor() {
    return new ChatMessageInteractor(
      getOwner(this),
      this.args.message,
      this.args.context
    );
  }

  get deletedAndCollapsed() {
    return this.args.message?.deletedAt && this.collapsed;
  }

  get hiddenAndCollapsed() {
    return this.args.message?.hidden && this.collapsed;
  }

  get collapsed() {
    return !this.args.message?.expanded;
  }

  get deletedMessageLabel() {
    let count = 1;

    const recursiveCount = (message) => {
      const previousMessage = message.previousMessage;
      if (previousMessage?.deletedAt) {
        count++;
        recursiveCount(previousMessage);
      }
    };

    recursiveCount(this.args.message);

    return I18n.t("chat.deleted", { count });
  }

  get shouldRender() {
    return (
      this.args.message.expanded ||
      !this.args.message.deletedAt ||
      (this.args.message.deletedAt && !this.args.message.nextMessage?.deletedAt)
    );
  }

  get shouldRenderOpenEmojiPickerButton() {
    return this.chat.userCanInteractWithChat && this.site.desktopView;
  }

  get secondaryActionsIsExpanded() {
    return document.querySelector(
      ".more-buttons.secondary-actions.is-expanded"
    );
  }

  @action
  expand() {
    const recursiveExpand = (message) => {
      const previousMessage = message.previousMessage;
      if (previousMessage?.deletedAt) {
        previousMessage.expanded = true;
        recursiveExpand(previousMessage);
      }
    };

    this.args.message.expanded = true;
    this.refreshStatusOnMentions();
    recursiveExpand(this.args.message);
  }

  @action
  toggleChecked(event) {
    event.stopPropagation();

    if (event.shiftKey) {
      this.messageInteractor.bulkSelect(event.target.checked);
      return;
    }

    this.messageInteractor.select(event.target.checked);
  }

  @action
  willDestroyMessage() {
    cancel(this._invitationSentTimer);
    cancel(this._disableMessageActionsHandler);
    cancel(this._makeMessageActiveHandler);
    cancel(this._debounceDecorateCookedMessageHandler);
    this.#teardownMentionedUsers();
    this.chat.activeMessage = null;
  }

  @action
  refreshStatusOnMentions() {
    schedule("afterRender", () => {
      this.args.message.mentionedUsers.forEach((user) => {
        const href = `/u/${user.username.toLowerCase()}`;
        const mentions = this.messageContainer.querySelectorAll(
          `a.mention[href="${href}"]`
        );

        mentions.forEach((mention) => {
          updateUserStatusOnMention(getOwner(this), mention, user.status);
        });
      });
    });
  }

  @action
  didInsertMessage(element) {
    this.messageContainer = element;
    this.initMentionedUsers();
    this.decorateMentions(element);
    this.debounceDecorateCookedMessage();
    this.refreshStatusOnMentions();
  }

  @action
  didUpdateMessageId() {
    this.debounceDecorateCookedMessage();
  }

  @action
  didUpdateMessageVersion() {
    this.debounceDecorateCookedMessage();
    this.refreshStatusOnMentions();
    this.initMentionedUsers();
  }

  debounceDecorateCookedMessage() {
    this._debounceDecorateCookedMessageHandler = discourseDebounce(
      this,
      this.decorateCookedMessage,
      this.args.message,
      100
    );
  }

  initMentionedUsers() {
    this.args.message.mentionedUsers.forEach((user) => {
      if (!user.statusManager.isTrackingStatus()) {
        user.statusManager.trackStatus();
        user.on("status-changed", this, "refreshStatusOnMentions");
      }
    });
  }

  decorateMentions(cooked) {
    if (this.args.message.channel.allowChannelWideMentions) {
      const wideMentions = [...cooked.querySelectorAll("span.mention")];
      MENTION_KEYWORDS.forEach((keyword) => {
        const mentions = wideMentions.filter((node) => {
          return node.textContent.trim() === `@${keyword}`;
        });

        const classes = applyValueTransformer("mentions-class", [], {
          user: { username: keyword },
        });

        mentions.forEach((mention) => {
          mention.classList.add(...classes);
        });
      });
    }

    this.args.message.mentionedUsers.forEach((user) => {
      const href = getURL(`/u/${user.username.toLowerCase()}`);
      const mentions = cooked.querySelectorAll(`a.mention[href="${href}"]`);
      const classes = applyValueTransformer("mentions-class", [], {
        user,
      });

      mentions.forEach((mention) => {
        mention.classList.add(...classes);
      });
    });
  }

  @action
  decorateCookedMessage(message) {
    schedule("afterRender", () => {
      _chatMessageDecorators.forEach((decorator) => {
        decorator.call(this, this.messageContainer, message.channel);
      });
    });
  }

  get show() {
    return (
      !this.args.message?.deletedAt ||
      this.currentUser.id === this.args.message?.user?.id ||
      this.currentUser.staff ||
      this.args.message?.channel?.canModerate
    );
  }

  @action
  onMouseEnter() {
    if (this.site.mobileView) {
      return;
    }

    if (this.chat.activeMessage?.model?.id === this.args.message.id) {
      return;
    }

    if (!this.secondaryActionsIsExpanded) {
      this._onMouseEnterMessageDebouncedHandler = discourseDebounce(
        this,
        this._debouncedOnHoverMessage,
        250
      );
    }
  }

  @action
  onMouseMove() {
    if (this.site.mobileView) {
      return;
    }

    if (this.chat.activeMessage?.model?.id === this.args.message.id) {
      return;
    }

    if (!this.secondaryActionsIsExpanded) {
      this._setActiveMessage();
    }
  }

  @action
  onMouseLeave(event) {
    cancel(this._onMouseEnterMessageDebouncedHandler);

    if (this.site.mobileView) {
      return;
    }

    if (
      (event.toElement || event.relatedTarget)?.closest(
        ".chat-message-actions-container"
      )
    ) {
      return;
    }
    if (!this.secondaryActionsIsExpanded) {
      this.chat.activeMessage = null;
    }
  }

  @bind
  _debouncedOnHoverMessage() {
    this._setActiveMessage();
  }

  _setActiveMessage() {
    if (this.args.disableMouseEvents) {
      return;
    }

    cancel(this._onMouseEnterMessageDebouncedHandler);

    if (!this.chat.userCanInteractWithChat) {
      return;
    }

    if (!this.args.message.expanded) {
      return;
    }

    this.chat.activeMessage = {
      model: this.args.message,
      context: this.args.context,
    };
  }

  @action
  onLongPressStart(element, event) {
    if (!this.args.message.expanded || !this.args.message.persisted) {
      return;
    }

    if (event.target.tagName === "IMG") {
      return;
    }

    // prevents message to show as active when starting scroll
    // at this moment scroll has no momentum and the row can
    // capture the touch event instead of a scroll
    this._makeMessageActiveHandler = discourseLater(() => {
      this.isActive = true;
    }, 125);
  }

  @action
  onLongPressCancel() {
    cancel(this._makeMessageActiveHandler);
    this.isActive = false;

    // this a tricky bit of code which is needed to prevent the long press
    // from triggering a click on the message actions panel when releasing finger press
    // we can't prevent default as we need to keep the event passive for performance reasons
    // this class will prevent any click from being triggered until removed
    // this number has been chosen from testing but might need to be increased
    this._disableMessageActionsHandler = discourseLater(() => {
      document.documentElement.classList.remove(
        "disable-message-actions-touch"
      );
    }, 200);
  }

  @action
  onLongPressEnd(element, event) {
    if (event.target.tagName === "IMG") {
      return;
    }

    cancel(this._makeMessageActiveHandler);
    this.isActive = false;

    if (isZoomed()) {
      // if zoomed don't handle long press
      return;
    }

    document.documentElement.classList.add("disable-message-actions-touch");
    document.activeElement.blur();
    document.querySelector(".chat-composer__input")?.blur();

    this._setActiveMessage();
    this.modal.show(ChatMessageActionsMobileModal);
  }

  get hasActiveState() {
    return (
      this.isActive ||
      this.chat.activeMessage?.model?.id === this.args.message.id
    );
  }

  get hasReply() {
    return this.args.message.inReplyTo && !this.hideReplyToInfo;
  }

  get hideUserInfo() {
    const message = this.args.message;

    const previousMessage = message.previousMessage;

    if (!previousMessage) {
      return false;
    }

    // this is a micro optimization to avoid layout changes when we load more messages
    if (message.firstOfResults) {
      return false;
    }

    if (message.chatWebhookEvent) {
      return false;
    }

    if (previousMessage.deletedAt) {
      return false;
    }

    if (
      Math.abs(
        new Date(message.createdAt) - new Date(previousMessage.createdAt)
      ) > 300000
    ) {
      return false;
    }

    if (message.inReplyTo) {
      if (message.inReplyTo?.id === previousMessage.id) {
        return message.user?.id === previousMessage.user?.id;
      } else {
        return false;
      }
    }

    return message.user?.id === previousMessage.user?.id;
  }

  get hideReplyToInfo() {
    return (
      this.threadContext ||
      this.args.message?.inReplyTo?.id ===
        this.args.message?.previousMessage?.id ||
      this.threadingEnabled
    );
  }

  get threadingEnabled() {
    return (
      (this.args.message?.channel?.threadingEnabled ||
        this.args.message?.thread?.force) &&
      !!this.args.message?.thread
    );
  }

  get showThreadIndicator() {
    return (
      !this.threadContext &&
      this.threadingEnabled &&
      this.args.message?.thread &&
      this.args.message?.thread.preview.replyCount > 0
    );
  }

  get threadContext() {
    return this.args.context === MESSAGE_CONTEXT_THREAD;
  }

  get shouldRenderStopMessageStreamingButton() {
    return (
      this.args.message.streaming &&
      (this.currentUser.admin ||
        this.args.message.inReplyTo?.user?.id === this.currentUser.id)
    );
  }

  @action
  stopMessageStreaming(message) {
    this.chatApi.stopMessageStreaming(message.channel.id, message.id);
  }

  #teardownMentionedUsers() {
    this.args.message.mentionedUsers.forEach((user) => {
      user.statusManager.stopTrackingStatus();
      user.off("status-changed", this, "refreshStatusOnMentions");
    });
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    {{#if this.shouldRender}}
      <ChatMessageSeparator
        @fetchMessagesByDate={{@fetchMessagesByDate}}
        @message={{@message}}
      />

      <div
        class={{concatClass
          "chat-message-container"
          (if this.pane.selectingMessages "-selectable")
          (if @message.highlighted "-highlighted")
          (if @message.streaming "-streaming")
          (if (lt @message.user.id 0) "is-bot")
          (if (eq @message.user.id this.currentUser.id) "is-by-current-user")
          (if (eq @message.id this.currentUser.id) "is-by-current-user")
          (if
            (eq
              @message.id
              @message.channel.currentUserMembership.lastReadMessageId
            )
            "-last-read"
          )
          (if @message.staged "-staged" "-persisted")
          (if @message.processed "-processed" "-not-processed")
          (if this.hasActiveState "-active")
          (if @message.bookmark "-bookmarked")
          (if @message.deletedAt "-deleted")
          (if @message.selected "-selected")
          (if @message.error "-errored")
          (if this.showThreadIndicator "has-thread-indicator")
          (if this.hideUserInfo "-user-info-hidden")
          (if this.hasReply "has-reply")
        }}
        data-id={{@message.id}}
        data-thread-id={{@message.thread.id}}
        {{didInsert this.didInsertMessage}}
        {{didUpdate this.didUpdateMessageId @message.id}}
        {{didUpdate this.didUpdateMessageVersion @message.version}}
        {{willDestroy this.willDestroyMessage}}
        {{on "mouseenter" this.onMouseEnter passive=true}}
        {{on "mouseleave" this.onMouseLeave passive=true}}
        {{on "mousemove" this.onMouseMove passive=true}}
        {{this.toggleCheckIfPossible}}
        {{ChatOnLongPress
          this.onLongPressStart
          this.onLongPressEnd
          this.onLongPressCancel
        }}
        ...attributes
      >
        {{#if this.show}}
          {{#if this.pane.selectingMessages}}
            <Input
              @type="checkbox"
              class="chat-message-selector"
              @checked={{@message.selected}}
              {{on "click" this.toggleChecked}}
            />
          {{/if}}

          {{#if this.deletedAndCollapsed}}
            <div class="chat-message-text -deleted">
              <DButton
                @action={{this.expand}}
                @translatedLabel={{this.deletedMessageLabel}}
                class="btn-flat chat-message-expand"
              />
            </div>
          {{else if this.hiddenAndCollapsed}}
            <div class="chat-message-text -hidden">
              <DButton
                @action={{this.expand}}
                @label="chat.hidden"
                class="btn-flat chat-message-expand"
              />
            </div>
          {{else}}
            <div class="chat-message">
              {{#unless this.hideReplyToInfo}}
                <ChatMessageInReplyToIndicator @message={{@message}} />
              {{/unless}}

              {{#if this.hideUserInfo}}
                <ChatMessageLeftGutter
                  @message={{@message}}
                  @threadContext={{this.threadContext}}
                />
              {{else}}
                <ChatMessageAvatar @message={{@message}} />
              {{/if}}

              <div class="chat-message-content">
                <ChatMessageInfo
                  @message={{@message}}
                  @show={{not this.hideUserInfo}}
                  @threadContext={{this.threadContext}}
                />

                <ChatMessageText
                  @cooked={{@message.cooked}}
                  @uploads={{@message.uploads}}
                  @edited={{@message.edited}}
                >
                  {{#if @message.reactions.length}}
                    <div class="chat-message-reaction-list">
                      {{#each @message.reactions as |reaction|}}
                        <ChatMessageReaction
                          @reaction={{reaction}}
                          @onReaction={{this.messageInteractor.react}}
                          @message={{@message}}
                          @showTooltip={{true}}
                        />
                      {{/each}}

                      {{#if this.shouldRenderOpenEmojiPickerButton}}
                        <DButton
                          @action={{this.messageInteractor.openEmojiPicker}}
                          @icon="discourse-emojis"
                          @title="chat.react"
                          @forwardEvent={{true}}
                          class="chat-message-react-btn"
                        />
                      {{/if}}
                    </div>
                  {{/if}}
                </ChatMessageText>

                {{#if this.shouldRenderStopMessageStreamingButton}}
                  <div class="stop-streaming-btn-container">
                    <DButton
                      @class="stop-streaming-btn"
                      @icon="stop-circle"
                      @label="cancel"
                      @action={{fn this.stopMessageStreaming @message}}
                    />

                  </div>
                {{/if}}

                <ChatMessageError
                  @message={{@message}}
                  @onRetry={{@resendStagedMessage}}
                />
              </div>

              {{#if this.showThreadIndicator}}
                <ChatMessageThreadIndicator @message={{@message}} />
              {{/if}}
            </div>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
