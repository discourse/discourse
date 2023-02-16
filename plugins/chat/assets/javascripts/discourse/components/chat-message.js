import Bookmark from "discourse/models/bookmark";
import { openBookmarkModal } from "discourse/controllers/bookmark";
import { isTesting } from "discourse-common/config/environment";
import Component from "@glimmer/component";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";
import optionalService from "discourse/lib/optional-service";
import { bind } from "discourse-common/utils/decorators";
import EmberObject, { action } from "@ember/object";
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

  _hasSubscribedToAppEvents = false;
  _loadingReactions = [];

  constructor() {
    super(...arguments);

    this.args.message.id
      ? this._subscribeToAppEvents()
      : this._waitForIdToBePopulated();

    if (this.args.message.bookmark) {
      this.args.message.set(
        "bookmark",
        Bookmark.create(this.args.message.bookmark)
      );
    }

    this.cachedFavoritesReactions = this.chatEmojiReactionStore.favorites;
  }

  get deletedAndCollapsed() {
    return this.args.message?.get("deleted_at") && this.collapsed;
  }

  get hiddenAndCollapsed() {
    return this.args.message?.get("hidden") && this.collapsed;
  }

  get collapsed() {
    return !this.args.message?.get("expanded");
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
    if (this.args.message?.stagedId) {
      this.appEvents.off(
        `chat-message-staged-${this.args.message.stagedId}:id-populated`,
        this,
        "_subscribeToAppEvents"
      );
    }

    this.appEvents.off("chat:refresh-message", this, "_refreshedMessage");

    this.appEvents.off(
      `chat-message-${this.args.message.id}:reaction`,
      this,
      "_handleReactionMessage"
    );

    cancel(this._invitationSentTimer);
  }

  @bind
  _refreshedMessage(message) {
    if (message.id === this.args.message.id) {
      this.decorateCookedMessage();
    }
  }

  @action
  decorateCookedMessage() {
    schedule("afterRender", () => {
      if (!this.messageContainer) {
        return;
      }

      _chatMessageDecorators.forEach((decorator) => {
        decorator.call(this, this.messageContainer, this.args.chatChannel);
      });
    });
  }

  get messageContainer() {
    const id = this.args.message?.id || this.args.message?.stagedId;
    return (
      id && document.querySelector(`.chat-message-container[data-id='${id}']`)
    );
  }

  _subscribeToAppEvents() {
    if (!this.args.message.id || this._hasSubscribedToAppEvents) {
      return;
    }

    this.appEvents.on("chat:refresh-message", this, "_refreshedMessage");

    this.appEvents.on(
      `chat-message-${this.args.message.id}:reaction`,
      this,
      "_handleReactionMessage"
    );
    this._hasSubscribedToAppEvents = true;
  }

  _waitForIdToBePopulated() {
    this.appEvents.on(
      `chat-message-staged-${this.args.message.stagedId}:id-populated`,
      this,
      "_subscribeToAppEvents"
    );
  }

  get showActions() {
    return (
      this.args.canInteractWithChat &&
      !this.args.message?.get("staged") &&
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
      this.args.chatChannel?.get("threading_enabled") &&
      this.args.message?.get("thread_id")
    );
  }

  get show() {
    return (
      !this.args.message?.get("deleted_at") ||
      this.currentUser.id === this.args.message?.get("user.id") ||
      this.currentUser.staff ||
      this.args.details?.can_moderate
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
      this.args.message?.get("hideUserInfo") &&
      !this.args.message?.get("chat_webhook_event")
    );
  }

  get showEditButton() {
    return (
      !this.args.message?.get("deleted_at") &&
      this.currentUser?.id === this.args.message?.get("user.id") &&
      this.args.chatChannel?.canModifyMessages?.(this.currentUser)
    );
  }
  get canFlagMessage() {
    return (
      this.currentUser?.id !== this.args.message?.get("user.id") &&
      this.args.message?.get("user_flag_status") === undefined &&
      this.args.details?.can_flag &&
      !this.args.message?.get("chat_webhook_event") &&
      !this.args.message?.get("deleted_at")
    );
  }

  get canManageDeletion() {
    return this.currentUser?.id === this.args.message.get("user.id")
      ? this.args.details?.can_delete_self
      : this.args.details?.can_delete_others;
  }

  get canReply() {
    return (
      !this.args.message?.get("deleted_at") &&
      this.args.chatChannel?.canModifyMessages?.(this.currentUser)
    );
  }

  get canReact() {
    return (
      !this.args.message?.get("deleted_at") &&
      this.args.chatChannel?.canModifyMessages?.(this.currentUser)
    );
  }

  get showDeleteButton() {
    return (
      this.canManageDeletion &&
      !this.args.message?.get("deleted_at") &&
      this.args.chatChannel?.canModifyMessages?.(this.currentUser)
    );
  }

  get showRestoreButton() {
    return (
      this.canManageDeletion &&
      this.args.message?.get("deleted_at") &&
      this.args.chatChannel?.canModifyMessages?.(this.currentUser)
    );
  }

  get showBookmarkButton() {
    return this.args.chatChannel?.canModifyMessages?.(this.currentUser);
  }

  get showRebakeButton() {
    return (
      this.currentUser?.staff &&
      this.args.chatChannel?.canModifyMessages?.(this.currentUser)
    );
  }

  get hasReactions() {
    return Object.values(this.args.message.get("reactions")).some(
      (r) => r.count > 0
    );
  }

  get mentionWarning() {
    return this.args.message.get("mentionWarning");
  }

  get mentionedCannotSeeText() {
    return I18n.t("chat.mention_warning.cannot_see", {
      username: this.mentionWarning?.cannot_see?.[0]?.username,
      count: this.mentionWarning?.cannot_see?.length,
      others: this._othersTranslation(
        this.mentionWarning?.cannot_see?.length - 1
      ),
    });
  }

  get mentionedWithoutMembershipText() {
    return I18n.t("chat.mention_warning.without_membership", {
      username: this.mentionWarning?.without_membership?.[0]?.username,
      count: this.mentionWarning?.without_membership?.length,
      others: this._othersTranslation(
        this.mentionWarning?.without_membership?.length - 1
      ),
    });
  }

  get groupsWithDisabledMentions() {
    return I18n.t("chat.mention_warning.group_mentions_disabled", {
      group_name: this.mentionWarning?.group_mentions_disabled?.[0],
      count: this.mentionWarning?.group_mentions_disabled?.length,
      others: this._othersTranslation(
        this.mentionWarning?.group_mentions_disabled?.length - 1
      ),
    });
  }

  get groupsWithTooManyMembers() {
    return I18n.t("chat.mention_warning.too_many_members", {
      group_name: this.mentionWarning.groups_with_too_many_members?.[0],
      count: this.mentionWarning.groups_with_too_many_members?.length,
      others: this._othersTranslation(
        this.mentionWarning.groups_with_too_many_members?.length - 1
      ),
    });
  }

  _othersTranslation(othersCount) {
    return I18n.t("chat.mention_warning.warning_multiple", {
      count: othersCount,
    });
  }

  @action
  inviteMentioned() {
    const userIds = this.mentionWarning.without_membership.mapBy("id");

    ajax(`/chat/${this.args.message.chat_channel_id}/invite`, {
      method: "PUT",
      data: { user_ids: userIds, chat_message_id: this.args.message.id },
    }).then(() => {
      this.args.message.set("mentionWarning.invitationSent", true);
      this._invitationSentTimer = discourseLater(() => {
        this.args.message.set("mentionWarning", null);
      }, 3000);
    });

    return false;
  }

  @action
  dismissMentionWarning() {
    this.args.message.set("mentionWarning", null);
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

  @bind
  _handleReactionMessage(busData) {
    const loadingReactionIndex = this._loadingReactions.indexOf(busData.emoji);
    if (loadingReactionIndex > -1) {
      return this._loadingReactions.splice(loadingReactionIndex, 1);
    }

    this._updateReactionsList(busData.emoji, busData.action, busData.user);
    this.afterReactionAdded();
  }

  get capabilities() {
    return getOwner(this).lookup("capabilities:main");
  }

  @action
  react(emoji, reactAction) {
    if (
      !this.args.canInteractWithChat ||
      this._loadingReactions.includes(emoji)
    ) {
      return;
    }

    if (this.capabilities.canVibrate && !isTesting()) {
      navigator.vibrate(5);
    }

    if (this.site.mobileView) {
      this.args.onHoverMessage(null);
    }

    this._loadingReactions.push(emoji);
    this._updateReactionsList(emoji, reactAction, this.currentUser);

    if (reactAction === REACTIONS.add) {
      this.chatEmojiReactionStore.track(`:${emoji}:`);
    }

    return this._publishReaction(emoji, reactAction).then(() => {
      // creating reaction will create a membership if not present
      // so we will fully refresh if we were not members of the channel
      // already
      if (!this.args.chatChannel.isFollowing || this.args.chatChannel.isDraft) {
        return this.args.chatChannelsManager
          .getChannel(this.args.chatChannel.id)
          .then((reactedChannel) => {
            this.router.transitionTo("chat.channel", "-", reactedChannel.id);
          });
      }
    });
  }

  _updateReactionsList(emoji, reactAction, user) {
    const selfReacted = this.currentUser.id === user.id;
    if (this.args.message.reactions[emoji]) {
      if (
        selfReacted &&
        reactAction === REACTIONS.add &&
        this.args.message.reactions[emoji].reacted
      ) {
        // User is already has reaction added; do nothing
        return false;
      }

      let newCount =
        reactAction === REACTIONS.add
          ? this.args.message.reactions[emoji].count + 1
          : this.args.message.reactions[emoji].count - 1;

      this.args.message.reactions.set(`${emoji}.count`, newCount);
      if (selfReacted) {
        this.args.message.reactions.set(
          `${emoji}.reacted`,
          reactAction === REACTIONS.add
        );
      } else {
        this.args.message.reactions[emoji].users.pushObject(user);
      }

      this.args.message.notifyPropertyChange("reactions");
    } else {
      if (reactAction === REACTIONS.add) {
        this.args.message.reactions.set(emoji, {
          count: 1,
          reacted: selfReacted,
          users: selfReacted ? [] : [user],
        });
      }

      this.args.message.notifyPropertyChange("reactions");
    }
  }

  _publishReaction(emoji, reactAction) {
    return ajax(
      `/chat/${this.args.message.chat_channel_id}/react/${this.args.message.id}`,
      {
        type: "PUT",
        data: {
          react_action: reactAction,
          emoji,
        },
      }
    ).catch((errResult) => {
      popupAjaxError(errResult);
      this._updateReactionsList(emoji, REACTIONS.remove, this.currentUser);
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

  viewReplyOrThread() {
    if (this.hasThread) {
      this.router.transitionTo(
        "chat.channel.thread",
        this.args.message.thread_id
      );
    } else {
      this.args.replyMessageClicked(this.args.message.in_reply_to);
    }
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
      const model = EmberObject.create(this.args.message);
      model.set("username", model.get("user.username"));
      model.set("user_id", model.get("user.id"));
      let controller = showModal("flag", { model });

      controller.setProperties({ flagTarget: new ChatMessageFlag() });
    } else {
      this._legacyFlag();
    }
  }

  @action
  expand() {
    this.args.message.set("expanded", true);
  }

  @action
  restore() {
    return ajax(
      `/chat/${this.args.message.chat_channel_id}/restore/${this.args.message.id}`,
      {
        type: "PUT",
      }
    ).catch(popupAjaxError);
  }

  @action
  openThread() {
    this.router.transitionTo(
      "chat.channel.thread",
      this.args.message.thread_id
    );
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
          this.args.message.set("bookmark", bookmark);
          this.appEvents.trigger(
            "bookmarks:changed",
            savedData,
            bookmark.attachedTo()
          );
        },
        onAfterDelete: () => {
          this.args.message.set("bookmark", null);
        },
      }
    );
  }

  @action
  rebakeMessage() {
    return ajax(
      `/chat/${this.args.message.chat_channel_id}/${this.args.message.id}/rebake`,
      {
        type: "PUT",
      }
    ).catch(popupAjaxError);
  }

  @action
  deleteMessage() {
    return ajax(
      `/chat/${this.args.message.chat_channel_id}/${this.args.message.id}`,
      {
        type: "DELETE",
      }
    ).catch(popupAjaxError);
  }

  @action
  toggleChecked(event) {
    if (event.shiftKey) {
      this.args.messageActionsHandler.bulkSelectMessages(
        this.args.message,
        event.target.checked
      );
    }

    this.args.messageActionsHandler.selectMessage(
      this.args.message,
      event.target.checked
    );
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
      `/chat/c/-/${this.args.message.chat_channel_id}/${this.args.message.id}`
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
    const favorites = this.cachedFavoritesReactions;

    // may be a {} if no defaults defined in some production builds
    if (!favorites || !favorites.slice) {
      return [];
    }

    const userReactions = Object.keys(this.args.message.reactions || {}).filter(
      (key) => {
        return this.args.message.reactions[key].reacted;
      }
    );

    return favorites.slice(0, 3).map((emoji) => {
      if (userReactions.includes(emoji)) {
        return { emoji, reacted: true };
      } else {
        return { emoji, reacted: false };
      }
    });
  }
}
