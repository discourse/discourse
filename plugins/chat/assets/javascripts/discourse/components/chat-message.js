import { action } from "@ember/object";
import Component from "@glimmer/component";
import I18n from "I18n";
import optionalService from "discourse/lib/optional-service";
import { ajax } from "discourse/lib/ajax";
import { cancel, schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import discourseLater from "discourse-common/lib/later";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import { getOwner } from "discourse-common/lib/get-owner";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import { updateUserStatusOnMention } from "discourse/lib/update-user-status-on-mention";
import { tracked } from "@glimmer/tracking";

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
          updateUserStatusOnMention(mention, user.status, this.currentUser);
        });
      });
    });
  }

  @action
  didInsertMessage(element) {
    this.messageContainer = element;
    this.decorateCookedMessage();
    this.refreshStatusOnMentions();
  }

  @action
  didUpdateMessageId() {
    this.decorateCookedMessage();
  }

  @action
  didUpdateMessageVersion() {
    this.decorateCookedMessage();
    this.refreshStatusOnMentions();
    this.initMentionedUsers();
  }

  @action
  decorateCookedMessage() {
    schedule("afterRender", () => {
      _chatMessageDecorators.forEach((decorator) => {
        decorator.call(this, this.messageContainer, this.args.message.channel);
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

    this._onMouseEnterMessageDebouncedHandler = discourseDebounce(
      this,
      this._debouncedOnHoverMessage,
      250
    );
  }

  @action
  onMouseMove() {
    if (this.site.mobileView) {
      return;
    }

    if (this.chat.activeMessage?.model?.id === this.args.message.id) {
      return;
    }

    this._setActiveMessage();
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

    this.chat.activeMessage = null;
  }

  @bind
  _debouncedOnHoverMessage() {
    this._setActiveMessage();
  }

  _setActiveMessage() {
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
  handleLongPressStart() {
    if (!this.args.message.expanded) {
      return;
    }

    this.isActive = true;
  }

  @action
  onLongPressCancel() {
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
  handleLongPressEnd() {
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

    ajax(`/chat/${this.args.message.channel.id}/invite`, {
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

  #teardownMentionedUsers() {
    this.args.message.mentionedUsers.forEach((user) => {
      user.stopTrackingStatus();
      user.off("status-changed", this, "refreshStatusOnMentions");
    });
  }
}
