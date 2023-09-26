import { action } from "@ember/object";
import Component from "@glimmer/component";
import I18n from "I18n";
import optionalService from "discourse/lib/optional-service";
import { cancel, schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import discourseLater from "discourse-common/lib/later";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import { getOwner } from "@ember/application";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import { updateUserStatusOnMention } from "discourse/lib/update-user-status-on-mention";
import { tracked } from "@glimmer/tracking";
import ChatMessageSeparatorDate from "discourse/plugins/chat/discourse/components/chat-message-separator-date";
import ChatMessageSeparatorNew from "discourse/plugins/chat/discourse/components/chat-message-separator-new";
import concatClass from "discourse/helpers/concat-class";
import DButton from "discourse/components/d-button";
import ChatMessageInReplyToIndicator from "discourse/plugins/chat/discourse/components/chat-message-in-reply-to-indicator";
import ChatMessageLeftGutter from "discourse/plugins/chat/discourse/components/chat/message/left-gutter";
import ChatMessageAvatar from "discourse/plugins/chat/discourse/components/chat/message/avatar";
import ChatMessageError from "discourse/plugins/chat/discourse/components/chat/message/error";
import ChatMessageInfo from "discourse/plugins/chat/discourse/components/chat/message/info";
import ChatMessageText from "discourse/plugins/chat/discourse/components/chat-message-text";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import ChatMessageThreadIndicator from "discourse/plugins/chat/discourse/components/chat-message-thread-indicator";
import eq from "truth-helpers/helpers/eq";
import not from "truth-helpers/helpers/not";
import { on } from "@ember/modifier";
import { Input } from "@ember/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
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
  <template>
    {{! template-lint-disable no-invalid-interactive }}
    {{! template-lint-disable modifier-name-case }}
    {{#if this.shouldRender}}
      {{#if (eq @context "channel")}}
        <ChatMessageSeparatorDate
          @fetchMessagesByDate={{@fetchMessagesByDate}}
          @message={{@message}}
        />
        <ChatMessageSeparatorNew @message={{@message}} />
      {{/if}}

      <div
        class={{concatClass
          "chat-message-container"
          (if this.pane.selectingMessages "-selectable")
          (if @message.highlighted "-highlighted")
          (if (eq @message.user.id this.currentUser.id) "is-by-current-user")
          (if @message.staged "-staged" "-persisted")
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
                <ChatMessageLeftGutter @message={{@message}} />
              {{else}}
                <ChatMessageAvatar @message={{@message}} />
              {{/if}}

              <div class="chat-message-content">
                <ChatMessageInfo
                  @message={{@message}}
                  @show={{not this.hideUserInfo}}
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

  @tracked isActive = false;

  @optionalService adminTools;

  constructor() {
    super(...arguments);
    this.initMentionedUsers();
  }

  get pane() {
    return this.args.context === MESSAGE_CONTEXT_THREAD
      ? this.chatThreadPane
      : this.chatChannelPane;
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
    if (event.shiftKey) {
      this.messageInteractor.bulkSelect(event.target.checked);
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

  @action
  decorateCookedMessage(message) {
    schedule("afterRender", () => {
      _chatMessageDecorators.forEach((decorator) => {
        decorator.call(this, this.messageContainer, message.channel);
      });
    });
  }

  @action
  initMentionedUsers() {
    this.args.message.mentionedUsers.forEach((user) => {
      if (user.isTrackingStatus()) {
        return;
      }

      user.trackStatus();
      user.on("status-changed", this, "refreshStatusOnMentions");
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
      this.args.context === MESSAGE_CONTEXT_THREAD ||
      this.args.message?.inReplyTo?.id ===
        this.args.message?.previousMessage?.id ||
      this.threadingEnabled
    );
  }

  get threadingEnabled() {
    return (
      this.args.message?.channel?.threadingEnabled &&
      !!this.args.message?.thread
    );
  }

  get showThreadIndicator() {
    return (
      this.args.context !== MESSAGE_CONTEXT_THREAD &&
      this.threadingEnabled &&
      this.args.message?.thread &&
      this.args.message?.thread.preview.replyCount > 0
    );
  }

  #teardownMentionedUsers() {
    this.args.message.mentionedUsers.forEach((user) => {
      user.stopTrackingStatus();
      user.off("status-changed", this, "refreshStatusOnMentions");
    });
  }
}
