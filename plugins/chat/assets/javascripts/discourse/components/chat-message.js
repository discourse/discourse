import { action } from "@ember/object";
import Component from "@glimmer/component";
import I18n from "I18n";
import optionalService from "discourse/lib/optional-service";
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
let _tippyInstances = [];

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

  get shouldRenderOpenEmojiPickerButton() {
    return this.chat.userCanInteractWithChat && this.site.desktopView;
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

  #destroyTippyInstances() {
    _tippyInstances.forEach((instance) => {
      instance.destroy();
    });
    _tippyInstances = [];
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
          updateUserStatusOnMention(mention, user.status, _tippyInstances);
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
    if (!this.args.message.expanded) {
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
    this.#destroyTippyInstances();
  }
}
