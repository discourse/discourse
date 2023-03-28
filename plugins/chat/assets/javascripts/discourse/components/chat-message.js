import { isTesting } from "discourse-common/config/environment";
import Component from "@glimmer/component";
import I18n from "I18n";
import optionalService from "discourse/lib/optional-service";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { cancel, schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import discourseLater from "discourse-common/lib/later";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import { getOwner } from "discourse-common/lib/get-owner";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

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
  @service chatEmojiReactionStore;
  @service chatEmojiPickerManager;
  @service chatChannelPane;
  @service chatChannelThreadPane;
  @service chatChannelsManager;
  @service router;

  @optionalService adminTools;

  get pane() {
    return this.args.context === MESSAGE_CONTEXT_THREAD
      ? this.chatChannelThreadPane
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

  @action
  expand() {
    this.args.message.expanded = true;
  }

  @action
  toggleChecked(event) {
    if (event.shiftKey) {
      this.messageInteractor.bulkSelect(event.target.checked);
    }

    this.messageInteractor.select(event.target.checked);
  }

  @action
  teardownChatMessage() {
    cancel(this._invitationSentTimer);
  }

  @action
  decorateCookedMessage() {
    schedule("afterRender", () => {
      if (!this.messageContainer) {
        return;
      }

      _chatMessageDecorators.forEach((decorator) => {
        decorator.call(this, this.messageContainer, this.args.channel);
      });
    });
  }

  get messageContainer() {
    const id = this.args.message?.id;
    if (id) {
      return document.querySelector(`.chat-message-container[data-id='${id}']`);
    }
  }

  get show() {
    return (
      !this.args.message?.deletedAt ||
      this.currentUser.id === this.args.message?.user?.id ||
      this.currentUser.staff ||
      this.args.channel?.canModerate
    );
  }

  @action
  onMouseEnter() {
    if (this.site.mobileView) {
      return;
    }

    if (this.pane.hoveredMessageId === this.args.message.id) {
      return;
    }

    this._onHoverMessageDebouncedHandler = discourseDebounce(
      this,
      this._debouncedOnHoverMessage,
      250
    );
  }

  @action
  onMouseLeave(event) {
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

    cancel(this._onHoverMessageDebouncedHandler);

    this.chat.activeMessage = null;
  }

  @bind
  _debouncedOnHoverMessage() {
    if (!this.chat.userCanInteractWithChat) {
      return;
    }
    this._setActiveMessage();
  }

  _setActiveMessage() {
    this.chat.activeMessage = {
      model: this.args.message,
      context: this.args.context,
    };
    this.pane.hoveredMessageId = this.args.message.id;
  }

  @action
  handleTouchStart() {
    // if zoomed don't track long press
    if (isZoomed()) {
      return;
    }

    // when testing this must be triggered immediately because there
    // is no concept of "long press" there, the Ember `tap` test helper
    // does send the touchstart/touchend events but immediately, see
    // https://github.com/emberjs/ember-test-helpers/blob/master/API.md#tap
    if (isTesting()) {
      this._handleLongPress();
    }

    this._isPressingHandler = discourseLater(this._handleLongPress, 500);
  }

  @action
  handleTouchMove() {
    cancel(this._isPressingHandler);
  }

  @action
  handleTouchEnd() {
    cancel(this._isPressingHandler);
  }

  @action
  _handleLongPress() {
    if (isZoomed()) {
      // if zoomed don't handle long press
      return;
    }

    document.activeElement.blur();
    document.querySelector(".chat-composer-input")?.blur();

    this._setActiveMessage();
  }

  get hideUserInfo() {
    const message = this.args.message;
    const previousMessage = message?.previousMessage;

    if (!previousMessage) {
      return false;
    }

    // this is a micro optimization to avoid layout changes when we load more messages
    if (message?.firstOfResults) {
      return false;
    }

    return (
      !message?.chatWebhookEvent &&
      (!message?.inReplyTo ||
        message?.inReplyTo?.user?.id !== message?.user?.id) &&
      !message?.previousMessage?.deletedAt &&
      Math.abs(
        new Date(message?.createdAt) - new Date(previousMessage?.createdAt)
      ) < 300000 && // If the time between messages is over 5 minutes, break.
      message?.user?.id === message?.previousMessage?.user?.id
    );
  }

  get hideReplyToInfo() {
    return (
      this.args.context === MESSAGE_CONTEXT_THREAD ||
      this.args.message?.inReplyTo?.id ===
        this.args.message?.previousMessage?.id
    );
  }

  get mentionWarning() {
    return this.args.message.mentionWarning;
  }

  get mentionedCannotSeeText() {
    return this._findTranslatedWarning(
      "chat.mention_warning.cannot_see",
      "chat.mention_warning.cannot_see_multiple",
      {
        username: this.mentionWarning?.cannot_see?.[0]?.username,
        count: this.mentionWarning?.cannot_see?.length,
      }
    );
  }

  get mentionedWithoutMembershipText() {
    return this._findTranslatedWarning(
      "chat.mention_warning.without_membership",
      "chat.mention_warning.without_membership_multiple",
      {
        username: this.mentionWarning?.without_membership?.[0]?.username,
        count: this.mentionWarning?.without_membership?.length,
      }
    );
  }

  get groupsWithDisabledMentions() {
    return this._findTranslatedWarning(
      "chat.mention_warning.group_mentions_disabled",
      "chat.mention_warning.group_mentions_disabled_multiple",
      {
        group_name: this.mentionWarning?.group_mentions_disabled?.[0],
        count: this.mentionWarning?.group_mentions_disabled?.length,
      }
    );
  }

  get groupsWithTooManyMembers() {
    return this._findTranslatedWarning(
      "chat.mention_warning.too_many_members",
      "chat.mention_warning.too_many_members_multiple",
      {
        group_name: this.mentionWarning.groups_with_too_many_members?.[0],
        count: this.mentionWarning.groups_with_too_many_members?.length,
      }
    );
  }

  _findTranslatedWarning(oneKey, multipleKey, args) {
    const translationKey = args.count === 1 ? oneKey : multipleKey;
    args.count--;
    return I18n.t(translationKey, args);
  }

  @action
  inviteMentioned() {
    const userIds = this.mentionWarning.without_membership.mapBy("id");

    ajax(`/chat/${this.args.message.channelId}/invite`, {
      method: "PUT",
      data: { user_ids: userIds, chat_message_id: this.args.message.id },
    }).then(() => {
      this.args.message.mentionWarning.set("invitationSent", true);
      this._invitationSentTimer = discourseLater(() => {
        this.dismissMentionWarning();
      }, 3000);
    });

    return false;
  }

  @action
  dismissMentionWarning() {
    this.args.message.mentionWarning = null;
  }
}
