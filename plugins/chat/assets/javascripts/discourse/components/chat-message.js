import Bookmark from "discourse/models/bookmark";
import { openBookmarkModal } from "discourse/controllers/bookmark";
import { isTesting } from "discourse-common/config/environment";
import Component from "@glimmer/component";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";
import optionalService from "discourse/lib/optional-service";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { cancel, schedule } from "@ember/runloop";
import { clipboardCopy } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse-common/lib/later";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import showModal from "discourse/lib/show-modal";
import ChatMessageFlag from "discourse/plugins/chat/discourse/lib/chat-message-flag";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "discourse-common/lib/get-owner";
import ChatMessageReaction from "discourse/plugins/chat/discourse/models/chat-message-reaction";

let _chatMessageDecorators = [];

export function addChatMessageDecorator(decorator) {
  _chatMessageDecorators.push(decorator);
}

export function resetChatMessageDecorators() {
  _chatMessageDecorators = [];
}

export const MENTION_KEYWORDS = ["here", "all"];

export const REACTIONS = { add: "add", remove: "remove" };

export default class ChatMessage extends Component {
  @service site;
  @service dialog;
  @service currentUser;
  @service appEvents;
  @service chat;
  @service chatEmojiReactionStore;
  @service chatEmojiPickerManager;
  @service chatChannelsManager;
  @service router;

  @tracked chatMessageActionsMobileAnchor = null;
  @tracked chatMessageActionsDesktopAnchor = null;

  @optionalService adminTools;

  cachedFavoritesReactions = null;

  constructor() {
    super(...arguments);

    this.cachedFavoritesReactions = this.chatEmojiReactionStore.favorites;
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
  setMessageActionsAnchors() {
    schedule("afterRender", () => {
      this.chatMessageActionsDesktopAnchor = document.querySelector(
        ".chat-message-actions-desktop-anchor"
      );
      this.chatMessageActionsMobileAnchor = document.querySelector(
        ".chat-message-actions-mobile-anchor"
      );
    });
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

    const stagedId = this.args.message?.stagedId;
    if (stagedId) {
      return document.querySelector(
        `.chat-message-container[data-staged-id='${stagedId}']`
      );
    }
  }

  get showActions() {
    return (
      this.args.canInteractWithChat &&
      !this.args.message?.staged &&
      this.args.isHovered
    );
  }

  get secondaryButtons() {
    const buttons = [];

    buttons.push({
      id: "copyLinkToMessage",
      name: I18n.t("chat.copy_link"),
      icon: "link",
    });

    if (this.showEditButton) {
      buttons.push({
        id: "edit",
        name: I18n.t("chat.edit"),
        icon: "pencil-alt",
      });
    }

    if (!this.args.selectingMessages) {
      buttons.push({
        id: "selectMessage",
        name: I18n.t("chat.select"),
        icon: "tasks",
      });
    }

    if (this.canFlagMessage) {
      buttons.push({
        id: "flag",
        name: I18n.t("chat.flag"),
        icon: "flag",
      });
    }

    if (this.showDeleteButton) {
      buttons.push({
        id: "deleteMessage",
        name: I18n.t("chat.delete"),
        icon: "trash-alt",
      });
    }

    if (this.showRestoreButton) {
      buttons.push({
        id: "restore",
        name: I18n.t("chat.restore"),
        icon: "undo",
      });
    }

    if (this.showRebakeButton) {
      buttons.push({
        id: "rebakeMessage",
        name: I18n.t("chat.rebake_message"),
        icon: "sync-alt",
      });
    }

    if (this.hasThread) {
      buttons.push({
        id: "openThread",
        name: I18n.t("chat.threads.open"),
        icon: "puzzle-piece",
      });
    }

    return buttons;
  }

  get messageActions() {
    return {
      reply: this.reply,
      react: this.react,
      copyLinkToMessage: this.copyLinkToMessage,
      edit: this.edit,
      selectMessage: this.selectMessage,
      flag: this.flag,
      deleteMessage: this.deleteMessage,
      restore: this.restore,
      rebakeMessage: this.rebakeMessage,
      toggleBookmark: this.toggleBookmark,
      openThread: this.openThread,
      startReactionForMessageActions: this.startReactionForMessageActions,
    };
  }

  get messageCapabilities() {
    return {
      canReact: this.canReact,
      canReply: this.canReply,
      canBookmark: this.showBookmarkButton,
      hasThread: this.canReply && this.hasThread,
    };
  }

  get hasThread() {
    return (
      this.args.channel?.get("threading_enabled") && this.args.message?.threadId
    );
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
  handleTouchStart() {
    // if zoomed don't track long press
    if (isZoomed()) {
      return;
    }

    if (!this.args.isHovered) {
      // when testing this must be triggered immediately because there
      // is no concept of "long press" there, the Ember `tap` test helper
      // does send the touchstart/touchend events but immediately, see
      // https://github.com/emberjs/ember-test-helpers/blob/master/API.md#tap
      if (isTesting()) {
        this._handleLongPress();
      }

      this._isPressingHandler = discourseLater(this._handleLongPress, 500);
    }
  }

  @action
  handleTouchMove() {
    if (!this.args.isHovered) {
      cancel(this._isPressingHandler);
    }
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

    this.args.onHoverMessage?.(this.args.message);
  }

  get hideUserInfo() {
    return (
      !this.args.message?.chatWebhookEvent &&
      !this.inReplyTo &&
      !this.args.message?.previousMessage?.deletedAt &&
      Math.abs(new Date(this.createdAt) - new Date(this.createdAt)) < 300000 && // If the time between messages is over 5 minutes, break.
      this.user.id === this.args.message?.previousMessage?.user?.id
    );
  }

  get hideReplyToInfo() {
    return (
      this.args.message?.inReplyTo?.id ===
      this.args.message?.previousMessage?.id
    );
  }

  get showEditButton() {
    return (
      !this.args.message?.deletedAt &&
      this.currentUser?.id === this.args.message?.user?.id &&
      this.args.channel?.canModifyMessages?.(this.currentUser)
    );
  }
  get canFlagMessage() {
    return (
      this.currentUser?.id !== this.args.message?.user?.id &&
      !this.args.channel?.isDirectMessageChannel &&
      this.args.message?.userFlagStatus === undefined &&
      this.args.channel?.canFlag &&
      !this.args.message?.chatWebhookEvent &&
      !this.args.message?.deletedAt
    );
  }

  get canManageDeletion() {
    return this.currentUser?.id === this.args.message.user.id
      ? this.args.channel?.canDeleteSelf
      : this.args.channel?.canDeleteOthers;
  }

  get canReply() {
    return (
      !this.args.message?.deletedAt &&
      this.args.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get canReact() {
    return (
      !this.args.message?.deletedAt &&
      this.args.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get showDeleteButton() {
    return (
      this.canManageDeletion &&
      !this.args.message?.deletedAt &&
      this.args.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get showRestoreButton() {
    return (
      this.canManageDeletion &&
      this.args.message?.deletedAt &&
      this.args.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get showBookmarkButton() {
    return this.args.channel?.canModifyMessages?.(this.currentUser);
  }

  get showRebakeButton() {
    return (
      this.currentUser?.staff &&
      this.args.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get hasReactions() {
    return Object.values(this.args.message.reactions).some((r) => r.count > 0);
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

  @action
  startReactionForMessageActions() {
    this.chatEmojiPickerManager.startFromMessageActions(
      this.args.message,
      this.selectReaction,
      { desktop: this.site.desktopView }
    );
  }

  @action
  startReactionForReactionList() {
    this.chatEmojiPickerManager.startFromMessageReactionList(
      this.args.message,
      this.selectReaction,
      { desktop: this.site.desktopView }
    );
  }

  deselectReaction(emoji) {
    if (!this.args.canInteractWithChat) {
      return;
    }

    this.react(emoji, REACTIONS.remove);
  }

  @action
  selectReaction(emoji) {
    if (!this.args.canInteractWithChat) {
      return;
    }

    this.react(emoji, REACTIONS.add);
  }

  get capabilities() {
    return getOwner(this).lookup("capabilities:main");
  }

  @action
  react(emoji, reactAction) {
    if (!this.args.canInteractWithChat) {
      return;
    }

    if (this.capabilities.canVibrate && !isTesting()) {
      navigator.vibrate(5);
    }

    if (this.site.mobileView) {
      this.args.onHoverMessage(null);
    }

    if (reactAction === REACTIONS.add) {
      this.chatEmojiReactionStore.track(`:${emoji}:`);
    }

    this.args.message.react(
      emoji,
      reactAction,
      this.currentUser,
      this.currentUser.id
    );

    return ajax(
      `/chat/${this.args.message.channelId}/react/${this.args.message.id}`,
      {
        type: "PUT",
        data: {
          react_action: reactAction,
          emoji,
        },
      }
    ).catch((errResult) => {
      popupAjaxError(errResult);
      this.args.message.react(
        emoji,
        REACTIONS.remove,
        this.currentUser,
        this.currentUser.id
      );
    });
  }

  // TODO(roman): For backwards-compatibility.
  //   Remove after the 3.0 release.
  _legacyFlag() {
    this.dialog.yesNoConfirm({
      message: I18n.t("chat.confirm_flag", {
        username: this.args.message.user?.username,
      }),
      didConfirm: () => {
        return ajax("/chat/flag", {
          method: "PUT",
          data: {
            chat_message_id: this.args.message.id,
            flag_type_id: 7, // notify_moderators
          },
        }).catch(popupAjaxError);
      },
    });
  }

  @action
  reply() {
    this.args.setReplyTo(this.args.message.id);
  }

  @action
  edit() {
    this.args.editButtonClicked(this.args.message.id);
  }

  @action
  flag() {
    const targetFlagSupported =
      requirejs.entries["discourse/lib/flag-targets/flag"];

    if (targetFlagSupported) {
      const model = this.args.message;
      model.username = model.user?.username;
      model.user_id = model.user?.id;
      let controller = showModal("flag", { model });
      controller.set("flagTarget", new ChatMessageFlag());
    } else {
      this._legacyFlag();
    }
  }

  @action
  expand() {
    this.args.message.expanded = true;
  }

  @action
  restore() {
    return ajax(
      `/chat/${this.args.message.channelId}/restore/${this.args.message.id}`,
      {
        type: "PUT",
      }
    ).catch(popupAjaxError);
  }

  @action
  openThread() {
    this.router.transitionTo("chat.channel.thread", this.args.message.threadId);
  }

  @action
  toggleBookmark() {
    return openBookmarkModal(
      this.args.message.bookmark ||
        Bookmark.createFor(
          this.currentUser,
          "ChatMessage",
          this.args.message.id
        ),
      {
        onAfterSave: (savedData) => {
          const bookmark = Bookmark.create(savedData);
          this.args.message.bookmark = bookmark;
          this.appEvents.trigger(
            "bookmarks:changed",
            savedData,
            bookmark.attachedTo()
          );
        },
        onAfterDelete: () => {
          this.args.message.bookmark = null;
        },
      }
    );
  }

  @action
  rebakeMessage() {
    return ajax(
      `/chat/${this.args.message.channelId}/${this.args.message.id}/rebake`,
      {
        type: "PUT",
      }
    ).catch(popupAjaxError);
  }

  @action
  deleteMessage() {
    return ajax(
      `/chat/${this.args.message.channelId}/${this.args.message.id}`,
      {
        type: "DELETE",
      }
    ).catch(popupAjaxError);
  }

  @action
  selectMessage() {
    this.args.message.selected = true;
    this.args.onStartSelectingMessages(this.args.message);
  }

  @action
  toggleChecked(e) {
    if (e.shiftKey) {
      this.args.bulkSelectMessages(this.args.message, e.target.checked);
    }

    this.args.onSelectMessage(this.args.message);
  }

  @action
  copyLinkToMessage() {
    if (!this.messageContainer) {
      return;
    }

    this.messageContainer
      .querySelector(".link-to-message-btn")
      ?.classList?.add("copied");

    const { protocol, host } = window.location;
    let url = getURL(
      `/chat/c/-/${this.args.message.channelId}/${this.args.message.id}`
    );
    url = url.indexOf("/") === 0 ? protocol + "//" + host + url : url;
    clipboardCopy(url);

    discourseLater(() => {
      this.messageContainer
        ?.querySelector(".link-to-message-btn")
        ?.classList?.remove("copied");
    }, 250);
  }

  get emojiReactions() {
    let favorites = this.cachedFavoritesReactions;

    // may be a {} if no defaults defined in some production builds
    if (!favorites || !favorites.slice) {
      return [];
    }

    return favorites.slice(0, 3).map((emoji) => {
      return (
        this.args.message.reactions.find(
          (reaction) => reaction.emoji === emoji
        ) ||
        ChatMessageReaction.create({
          emoji,
        })
      );
    });
  }
}
