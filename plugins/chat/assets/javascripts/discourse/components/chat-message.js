import Bookmark from "discourse/models/bookmark";
import { openBookmarkModal } from "discourse/controllers/bookmark";
import { isTesting } from "discourse-common/config/environment";
import Component from "@ember/component";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";
import optionalService from "discourse/lib/optional-service";
import discourseComputed, {
  afterRender,
  bind,
} from "discourse-common/utils/decorators";
import EmberObject, { action, computed } from "@ember/object";
import { and, not } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { cancel, once } from "@ember/runloop";
import { clipboardCopy } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse-common/lib/later";
import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import showModal from "discourse/lib/show-modal";
import ChatMessageFlag from "discourse/plugins/chat/discourse/lib/chat-message-flag";

let _chatMessageDecorators = [];

export function addChatMessageDecorator(decorator) {
  _chatMessageDecorators.push(decorator);
}

export function resetChatMessageDecorators() {
  _chatMessageDecorators = [];
}

export const MENTION_KEYWORDS = ["here", "all"];

export default Component.extend({
  ADD_REACTION: "add",
  REMOVE_REACTION: "remove",
  SHOW_LEFT: "showLeft",
  SHOW_RIGHT: "showRight",
  canInteractWithChat: false,
  isHovered: false,
  onHoverMessage: null,
  chatEmojiReactionStore: service("chat-emoji-reaction-store"),
  chatEmojiPickerManager: service("chat-emoji-picker-manager"),
  chatChannelsManager: service("chat-channels-manager"),
  adminTools: optionalService(),
  _hasSubscribedToAppEvents: false,
  tagName: "",
  chat: service(),
  dialog: service(),
  router: service(),
  chatMessageActionsMobileAnchor: null,
  chatMessageActionsDesktopAnchor: null,
  chatMessageEmojiPickerAnchor: null,
  cachedFavoritesReactions: null,

  init() {
    this._super(...arguments);

    this.set("_loadingReactions", []);
    this.message.set("reactions", EmberObject.create(this.message.reactions));
    this.message.id
      ? this._subscribeToAppEvents()
      : this._waitForIdToBePopulated();
    if (this.message.bookmark) {
      this.set("message.bookmark", Bookmark.create(this.message.bookmark));
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this.set(
      "chatMessageActionsMobileAnchor",
      document.querySelector(".chat-message-actions-mobile-anchor")
    );
    this.set(
      "chatMessageActionsDesktopAnchor",
      document.querySelector(".chat-message-actions-desktop-anchor")
    );

    this.set("cachedFavoritesReactions", this.chatEmojiReactionStore.favorites);
  },

  willDestroyElement() {
    this._super(...arguments);
    if (this.message.stagedId) {
      this.appEvents.off(
        `chat-message-staged-${this.message.stagedId}:id-populated`,
        this,
        "_subscribeToAppEvents"
      );
    }

    this.appEvents.off("chat:refresh-message", this, "_refreshedMessage");

    this.appEvents.off(
      `chat-message-${this.message.id}:reaction`,
      this,
      "_handleReactionMessage"
    );

    cancel(this._invitationSentTimer);
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (!this.show || this.deletedAndCollapsed) {
      this._decoratedMessageCooked = null;
    } else if (this.message.cooked !== this._decoratedMessageCooked) {
      once("afterRender", this.decorateMessageCooked);
      this._decoratedMessageCooked = this.message.cooked;
    }
  },

  @bind
  _refreshedMessage(message) {
    if (message.id === this.message.id) {
      this.decorateMessageCooked();
    }
  },

  @bind
  decorateMessageCooked() {
    if (!this.messageContainer) {
      return;
    }

    _chatMessageDecorators.forEach((decorator) => {
      decorator.call(this, this.messageContainer, this.chatChannel);
    });
  },

  @computed("message.{id,stagedId}")
  get messageContainer() {
    const id = this.message?.id || this.message?.stagedId;
    return (
      id && document.querySelector(`.chat-message-container[data-id='${id}']`)
    );
  },

  _subscribeToAppEvents() {
    if (!this.message.id || this._hasSubscribedToAppEvents) {
      return;
    }

    this.appEvents.on("chat:refresh-message", this, "_refreshedMessage");

    this.appEvents.on(
      `chat-message-${this.message.id}:reaction`,
      this,
      "_handleReactionMessage"
    );
    this._hasSubscribedToAppEvents = true;
  },

  _waitForIdToBePopulated() {
    this.appEvents.on(
      `chat-message-staged-${this.message.stagedId}:id-populated`,
      this,
      "_subscribeToAppEvents"
    );
  },

  @discourseComputed("canInteractWithChat", "message.staged", "isHovered")
  showActions(canInteractWithChat, messageStaged, isHovered) {
    return canInteractWithChat && !messageStaged && isHovered;
  },

  deletedAndCollapsed: and("message.deleted_at", "collapsed"),
  hiddenAndCollapsed: and("message.hidden", "collapsed"),
  collapsed: not("message.expanded"),

  @discourseComputed(
    "selectingMessages",
    "canFlagMessage",
    "showDeleteButton",
    "showRestoreButton",
    "showEditButton",
    "showRebakeButton"
  )
  secondaryButtons() {
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

    if (!this.selectingMessages) {
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
  },

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
  },

  get messageCapabilities() {
    return {
      canReact: this.canReact,
      canReply: this.canReply,
      canBookmark: this.showBookmarkButton,
      hasThread: this.canReply && this.hasThread,
    };
  },

  @discourseComputed("message.thread_id")
  hasThread() {
    return this.chatChannel.threading_enabled && this.message.thread_id;
  },

  @discourseComputed("message", "details.can_moderate")
  show(message, canModerate) {
    return (
      !message.deleted_at ||
      this.currentUser.id === this.message.user.id ||
      this.currentUser.staff ||
      canModerate
    );
  },

  @action
  handleTouchStart() {
    // if zoomed don't track long press
    if (isZoomed()) {
      return;
    }

    if (!this.isHovered) {
      // when testing this must be triggered immediately because there
      // is no concept of "long press" there, the Ember `tap` test helper
      // does send the touchstart/touchend events but immediately, see
      // https://github.com/emberjs/ember-test-helpers/blob/master/API.md#tap
      if (isTesting()) {
        this._handleLongPress();
      }

      this._isPressingHandler = discourseLater(this._handleLongPress, 500);
    }
  },

  @action
  handleTouchMove() {
    if (!this.isHovered) {
      cancel(this._isPressingHandler);
    }
  },

  @action
  handleTouchEnd() {
    cancel(this._isPressingHandler);
  },

  @action
  _handleLongPress() {
    if (isZoomed()) {
      // if zoomed don't handle long press
      return;
    }

    document.activeElement.blur();
    document.querySelector(".chat-composer-input")?.blur();

    this.onHoverMessage(this.message);
  },

  @discourseComputed("message.hideUserInfo", "message.chat_webhook_event")
  hideUserInfo(hide, webhookEvent) {
    return hide && !webhookEvent;
  },

  @discourseComputed(
    "message.staged",
    "message.deleted_at",
    "message.in_reply_to",
    "message.error",
    "message.bookmark",
    "isHovered"
  )
  chatMessageClasses(staged, deletedAt, inReplyTo, error, bookmark, isHovered) {
    let classNames = ["chat-message"];

    if (staged) {
      classNames.push("chat-message-staged");
    }
    if (deletedAt) {
      classNames.push("deleted");
    }
    if (inReplyTo) {
      classNames.push("is-reply");
    }
    if (this.hideUserInfo) {
      classNames.push("user-info-hidden");
    }
    if (error) {
      classNames.push("errored");
    }
    if (isHovered) {
      classNames.push("chat-message-selected");
    }
    if (bookmark) {
      classNames.push("chat-message-bookmarked");
    }
    return classNames.join(" ");
  },

  @discourseComputed("message", "message.deleted_at", "chatChannel.status")
  showEditButton(message, deletedAt) {
    return (
      !deletedAt &&
      this.currentUser.id === message.user?.id &&
      this.chatChannel.canModifyMessages(this.currentUser)
    );
  },

  @discourseComputed(
    "message",
    "message.user_flag_status",
    "details.can_flag",
    "message.deleted_at"
  )
  canFlagMessage(message, userFlagStatus, canFlag, deletedAt) {
    return (
      this.currentUser?.id !== message.user?.id &&
      userFlagStatus === undefined &&
      canFlag &&
      !message.chat_webhook_event &&
      !deletedAt
    );
  },

  @discourseComputed("message")
  canManageDeletion(message) {
    return this.currentUser?.id === message.user?.id
      ? this.details.can_delete_self
      : this.details.can_delete_others;
  },

  @discourseComputed("message.deleted_at", "chatChannel.status")
  canReply(deletedAt) {
    return !deletedAt && this.chatChannel.canModifyMessages(this.currentUser);
  },

  @discourseComputed("message.deleted_at", "chatChannel.status")
  canReact(deletedAt) {
    return !deletedAt && this.chatChannel.canModifyMessages(this.currentUser);
  },

  @discourseComputed(
    "canManageDeletion",
    "message.deleted_at",
    "chatChannel.status"
  )
  showDeleteButton(canManageDeletion, deletedAt) {
    return (
      canManageDeletion &&
      !deletedAt &&
      this.chatChannel.canModifyMessages(this.currentUser)
    );
  },

  @discourseComputed(
    "canManageDeletion",
    "message.deleted_at",
    "chatChannel.status"
  )
  showRestoreButton(canManageDeletion, deletedAt) {
    return (
      canManageDeletion &&
      deletedAt &&
      this.chatChannel.canModifyMessages(this.currentUser)
    );
  },

  @discourseComputed("chatChannel.status")
  showBookmarkButton() {
    return this.chatChannel.canModifyMessages(this.currentUser);
  },

  @discourseComputed("chatChannel.status")
  showRebakeButton() {
    return (
      this.currentUser?.staff &&
      this.chatChannel.canModifyMessages(this.currentUser)
    );
  },

  @discourseComputed("message.reactions.@each")
  hasReactions(reactions) {
    return Object.values(reactions).some((r) => r.count > 0);
  },

  @discourseComputed("message.mentionWarning")
  mentionWarning() {
    return this.message.mentionWarning;
  },

  @discourseComputed("mentionWarning.cannot_see")
  mentionedCannotSeeText(users) {
    return I18n.t("chat.mention_warning.cannot_see", {
      username: users[0].username,
      count: users.length,
      others: this._othersTranslation(users.length - 1),
    });
  },

  @discourseComputed("mentionWarning.without_membership")
  mentionedWithoutMembershipText(users) {
    return I18n.t("chat.mention_warning.without_membership", {
      username: users[0].username,
      count: users.length,
      others: this._othersTranslation(users.length - 1),
    });
  },

  @discourseComputed("mentionWarning.group_mentions_disabled")
  groupsWithDisabledMentions(groups) {
    return I18n.t("chat.mention_warning.group_mentions_disabled", {
      group_name: groups[0],
      count: groups.length,
      others: this._othersTranslation(groups.length - 1),
    });
  },

  @discourseComputed("mentionWarning.groups_with_too_many_members")
  groupsWithTooManyMembers(groups) {
    return I18n.t("chat.mention_warning.too_many_members", {
      group_name: groups[0],
      count: groups.length,
      others: this._othersTranslation(groups.length - 1),
    });
  },

  _othersTranslation(othersCount) {
    return I18n.t("chat.mention_warning.warning_multiple", {
      count: othersCount,
    });
  },

  @action
  inviteMentioned() {
    const user_ids = this.mentionWarning.without_membership.mapBy("id");

    ajax(`/chat/${this.details.chat_channel_id}/invite`, {
      method: "PUT",
      data: { user_ids, chat_message_id: this.message.id },
    }).then(() => {
      this.message.set("mentionWarning.invitationSent", true);
      this._invitationSentTimer = discourseLater(() => {
        this.message.set("mentionWarning", null);
      }, 3000);
    });

    return false;
  },

  @action
  dismissMentionWarning() {
    this.message.set("mentionWarning", null);
  },

  @action
  startReactionForMessageActions() {
    this.chatEmojiPickerManager.startFromMessageActions(
      this.message,
      this.selectReaction,
      { desktop: this.site.desktopView }
    );
  },

  @action
  startReactionForReactionList() {
    this.chatEmojiPickerManager.startFromMessageReactionList(
      this.message,
      this.selectReaction,
      { desktop: this.site.desktopView }
    );
  },

  deselectReaction(emoji) {
    if (!this.canInteractWithChat) {
      return;
    }

    this.react(emoji, this.REMOVE_REACTION);
    this.notifyPropertyChange("emojiReactions");
  },

  @action
  selectReaction(emoji) {
    if (!this.canInteractWithChat) {
      return;
    }

    this.react(emoji, this.ADD_REACTION);
    this.notifyPropertyChange("emojiReactions");
  },

  @bind
  _handleReactionMessage(busData) {
    const loadingReactionIndex = this._loadingReactions.indexOf(busData.emoji);
    if (loadingReactionIndex > -1) {
      return this._loadingReactions.splice(loadingReactionIndex, 1);
    }

    this._updateReactionsList(busData.emoji, busData.action, busData.user);
    this.afterReactionAdded();
  },

  @action
  react(emoji, reactAction) {
    if (!this.canInteractWithChat || this._loadingReactions.includes(emoji)) {
      return;
    }

    if (this.capabilities.canVibrate && !isTesting()) {
      navigator.vibrate(5);
    }

    if (this.site.mobileView) {
      this.set("isHovered", false);
    }

    this._loadingReactions.push(emoji);
    this._updateReactionsList(emoji, reactAction, this.currentUser);

    if (reactAction === this.ADD_REACTION) {
      this.chatEmojiReactionStore.track(`:${emoji}:`);
    }

    return this._publishReaction(emoji, reactAction).then(() => {
      this.notifyPropertyChange("emojiReactions");

      // creating reaction will create a membership if not present
      // so we will fully refresh if we were not members of the channel
      // already
      if (!this.chatChannel.isFollowing || this.chatChannel.isDraft) {
        return this.chatChannelsManager
          .getChannel(this.chatChannel.id)
          .then((reactedChannel) => {
            this.router.transitionTo("chat.channel", "-", reactedChannel.id);
          });
      }
    });
  },

  _updateReactionsList(emoji, reactAction, user) {
    const selfReacted = this.currentUser.id === user.id;
    if (this.message.reactions[emoji]) {
      if (
        selfReacted &&
        reactAction === this.ADD_REACTION &&
        this.message.reactions[emoji].reacted
      ) {
        // User is already has reaction added; do nothing
        return false;
      }

      let newCount =
        reactAction === this.ADD_REACTION
          ? this.message.reactions[emoji].count + 1
          : this.message.reactions[emoji].count - 1;

      this.message.reactions.set(`${emoji}.count`, newCount);
      if (selfReacted) {
        this.message.reactions.set(
          `${emoji}.reacted`,
          reactAction === this.ADD_REACTION
        );
      } else {
        this.message.reactions[emoji].users.pushObject(user);
      }
    } else {
      if (reactAction === this.ADD_REACTION) {
        this.message.reactions.set(emoji, {
          count: 1,
          reacted: selfReacted,
          users: selfReacted ? [] : [user],
        });
      }
    }
    this.message.notifyPropertyChange("reactions");
  },

  _publishReaction(emoji, reactAction) {
    return ajax(
      `/chat/${this.details.chat_channel_id}/react/${this.message.id}`,
      {
        type: "PUT",
        data: {
          react_action: reactAction,
          emoji,
        },
      }
    ).catch((errResult) => {
      popupAjaxError(errResult);
      this._updateReactionsList(emoji, this.REMOVE_REACTION, this.currentUser);
    });
  },

  // TODO(roman): For backwards-compatibility.
  //   Remove after the 3.0 release.
  _legacyFlag() {
    this.dialog.yesNoConfirm({
      message: I18n.t("chat.confirm_flag", {
        username: this.message.user?.username,
      }),
      didConfirm: () => {
        return ajax("/chat/flag", {
          method: "PUT",
          data: {
            chat_message_id: this.message.id,
            flag_type_id: 7, // notify_moderators
          },
        }).catch(popupAjaxError);
      },
    });
  },

  @action
  reply() {
    this.setReplyTo(this.message.id);
  },

  @action
  viewReplyOrThread() {
    if (this.hasThread) {
      this.router.transitionTo("chat.channel.thread", this.message.thread_id);
    } else {
      this.replyMessageClicked(this.message.in_reply_to);
    }
  },

  @action
  edit() {
    this.editButtonClicked(this.message.id);
  },

  @action
  flag() {
    const targetFlagSupported =
      requirejs.entries["discourse/lib/flag-targets/flag"];

    if (targetFlagSupported) {
      const model = EmberObject.create(this.message);
      model.set("username", model.get("user.username"));
      model.set("user_id", model.get("user.id"));
      let controller = showModal("flag", { model });

      controller.setProperties({ flagTarget: new ChatMessageFlag() });
    } else {
      this._legacyFlag();
    }
  },

  @action
  expand() {
    this.message.set("expanded", true);
  },

  @action
  restore() {
    return ajax(
      `/chat/${this.details.chat_channel_id}/restore/${this.message.id}`,
      {
        type: "PUT",
      }
    ).catch(popupAjaxError);
  },

  @action
  openThread() {
    this.router.transitionTo("chat.channel.thread", this.message.thread_id);
  },

  @action
  toggleBookmark() {
    return openBookmarkModal(
      this.message.bookmark ||
        Bookmark.createFor(this.currentUser, "ChatMessage", this.message.id),
      {
        onAfterSave: (savedData) => {
          const bookmark = Bookmark.create(savedData);
          this.set("message.bookmark", bookmark);
          this.appEvents.trigger(
            "bookmarks:changed",
            savedData,
            bookmark.attachedTo()
          );
        },
        onAfterDelete: () => {
          this.set("message.bookmark", null);
        },
      }
    );
  },

  @action
  rebakeMessage() {
    return ajax(
      `/chat/${this.details.chat_channel_id}/${this.message.id}/rebake`,
      {
        type: "PUT",
      }
    ).catch(popupAjaxError);
  },

  @action
  deleteMessage() {
    return ajax(`/chat/${this.details.chat_channel_id}/${this.message.id}`, {
      type: "DELETE",
    }).catch(popupAjaxError);
  },

  @action
  selectMessage() {
    this.message.set("selected", true);
    this.onStartSelectingMessages(this.message);
  },

  @action
  @afterRender
  toggleChecked(e) {
    if (e.shiftKey) {
      this.bulkSelectMessages(this.message, e.target.checked);
    }

    this.onSelectMessage(this.message);
  },

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
      `/chat/c/-/${this.details.chat_channel_id}/${this.message.id}`
    );
    url = url.indexOf("/") === 0 ? protocol + "//" + host + url : url;
    clipboardCopy(url);

    discourseLater(() => {
      this.messageContainer
        ?.querySelector(".link-to-message-btn")
        ?.classList?.remove("copied");
    }, 250);
  },

  @computed
  get emojiReactions() {
    const favorites = this.cachedFavoritesReactions;

    // may be a {} if no defaults defined in some production builds
    if (!favorites || !favorites.slice) {
      return [];
    }

    const userReactions = Object.keys(this.message.reactions).filter((key) => {
      return this.message.reactions[key].reacted;
    });

    return favorites.slice(0, 3).map((emoji) => {
      if (userReactions.includes(emoji)) {
        return { emoji, reacted: true };
      } else {
        return { emoji, reacted: false };
      }
    });
  },
});
