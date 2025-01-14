import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import BookmarkModal from "discourse/components/modal/bookmark";
import FlagModal from "discourse/components/modal/flag";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import Bookmark from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";
import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";
import ChatMessageFlag from "discourse/plugins/chat/discourse/lib/chat-message-flag";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { REACTIONS } from "discourse/plugins/chat/discourse/models/chat-message-reaction";

const removedSecondaryActions = new Set();

export function removeChatComposerSecondaryActions(actionIds) {
  actionIds.forEach((id) => removedSecondaryActions.add(id));
}

export function resetRemovedChatComposerSecondaryActions() {
  removedSecondaryActions.clear();
}

export default class ChatemojiReactions {
  @service appEvents;
  @service dialog;
  @service chat;
  @service chatChannelComposer;
  @service chatThreadComposer;
  @service chatChannelPane;
  @service chatThreadPane;
  @service chatApi;
  @service currentUser;
  @service site;
  @service router;
  @service modal;
  @service capabilities;
  @service menu;
  @service toasts;
  @service interactedChatMessage;

  @tracked message = null;
  @tracked context = null;

  constructor(owner, message, context) {
    setOwner(this, owner);

    this.message = message;
    this.context = context;
  }

  get pane() {
    return this.context === MESSAGE_CONTEXT_THREAD
      ? this.chatThreadPane
      : this.chatChannelPane;
  }

  get canEdit() {
    return (
      !this.message.deletedAt &&
      this.currentUser.id === this.message.user.id &&
      this.message.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get canInteractWithMessage() {
    return (
      !this.message?.deletedAt &&
      this.message?.channel?.canModifyMessages(this.currentUser)
    );
  }

  get canRestoreMessage() {
    return (
      this.message?.deletedAt &&
      (this.currentUser.staff ||
        (this.message?.user?.id === this.currentUser.id &&
          this.message?.deletedById === this.currentUser.id)) &&
      this.message.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get canBookmark() {
    return this.message?.channel?.canModifyMessages?.(this.currentUser);
  }

  get canReply() {
    return (
      this.canInteractWithMessage && this.context !== MESSAGE_CONTEXT_THREAD
    );
  }

  get canReact() {
    return this.canInteractWithMessage;
  }

  get canFlagMessage() {
    return (
      this.currentUser.id !== this.message?.user?.id &&
      this.message?.userFlagStatus === undefined &&
      this.message.channel?.canFlag &&
      !this.message?.chatWebhookEvent &&
      !this.message?.deletedAt
    );
  }

  get canRebakeMessage() {
    return (
      this.currentUser.staff &&
      this.message.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get canDeleteMessage() {
    return (
      this.canDelete &&
      !this.message?.deletedAt &&
      this.message.channel?.canModifyMessages?.(this.currentUser)
    );
  }

  get canDelete() {
    return this.currentUser.id === this.message.user.id
      ? this.message.channel?.canDeleteSelf
      : this.message.channel?.canDeleteOthers;
  }

  get composer() {
    return this.context === MESSAGE_CONTEXT_THREAD
      ? this.chatThreadComposer
      : this.chatChannelComposer;
  }

  get secondaryActions() {
    const buttons = [];

    buttons.push({
      id: "copyLink",
      name: i18n("chat.copy_link"),
      icon: "link",
    });

    if (this.site.mobileView) {
      buttons.push({
        id: "copyText",
        name: i18n("chat.copy_text"),
        icon: "clipboard",
      });
    }

    if (this.canEdit) {
      buttons.push({
        id: "edit",
        name: i18n("chat.edit"),
        icon: "pencil",
      });
    }

    if (!this.pane.selectingMessages) {
      buttons.push({
        id: "select",
        name: i18n("chat.select"),
        icon: "list-check",
      });
    }

    if (this.canFlagMessage) {
      buttons.push({
        id: "flag",
        name: i18n("chat.flag"),
        icon: "flag",
      });
    }

    if (this.canDeleteMessage) {
      buttons.push({
        id: "delete",
        name: i18n("chat.delete"),
        icon: "trash-can",
      });
    }

    if (this.canRestoreMessage) {
      buttons.push({
        id: "restore",
        name: i18n("chat.restore"),
        icon: "arrow-rotate-left",
      });
    }

    if (this.canRebakeMessage) {
      buttons.push({
        id: "rebake",
        name: i18n("chat.rebake_message"),
        icon: "rotate",
      });
    }

    return buttons.reject((button) => removedSecondaryActions.has(button.id));
  }

  select(checked = true) {
    this.message.selected = checked;
    this.pane.onSelectMessage(this.message);
  }

  bulkSelect(checked) {
    const manager = this.message.manager;
    const lastSelectedIndex = manager.findIndexOfMessage(
      this.pane.lastSelectedMessage.id
    );
    const newlySelectedIndex = manager.findIndexOfMessage(this.message.id);
    const sortedIndices = [lastSelectedIndex, newlySelectedIndex].sort(
      (a, b) => a - b
    );

    for (let i = sortedIndices[0]; i <= sortedIndices[1]; i++) {
      manager.messages[i].selected = checked;
    }
  }

  copyText() {
    clipboardCopy(this.message.message);
    this.toasts.success({
      duration: 3000,
      data: { message: i18n("chat.text_copied") },
    });
  }

  copyLink() {
    const { protocol, host } = window.location;
    const channelId = this.message.channel.id;
    const threadId = this.message.thread?.id;

    let url;
    if (this.context === MESSAGE_CONTEXT_THREAD && threadId) {
      url = getURL(`/chat/c/-/${channelId}/t/${threadId}/${this.message.id}`);
    } else {
      url = getURL(`/chat/c/-/${channelId}/${this.message.id}`);
    }

    url = url.indexOf("/") === 0 ? protocol + "//" + host + url : url;
    clipboardCopy(url);
    this.toasts.success({
      duration: 1500,
      data: { message: i18n("chat.link_copied") },
    });
  }

  @action
  react(emoji, reactAction) {
    if (!this.chat.userCanInteractWithChat) {
      return;
    }

    if (this.pane.reacting) {
      return;
    }

    if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
      navigator.vibrate(5);
    }

    if (this.site.mobileView) {
      this.chat.activeMessage = null;
    }

    this.pane.reacting = true;

    this.message.react(
      emoji,
      reactAction,
      this.currentUser,
      this.currentUser.id
    );

    return this.chatApi
      .publishReaction(
        this.message.channel.id,
        this.message.id,
        emoji,
        reactAction
      )
      .catch((errResult) => {
        popupAjaxError(errResult);
        this.message.react(
          emoji,
          REACTIONS.remove,
          this.currentUser,
          this.currentUser.id
        );
      })
      .finally(() => {
        this.pane.reacting = false;
      });
  }

  @action
  toggleBookmark() {
    // somehow, this works around a low-level chrome rendering issue which
    // causes a complete browser crash when saving/deleting bookmarks in chat.
    // Error message: "Check failed: !NeedsToUpdateCachedValues()."
    // Internal topic: t/143485
    // Hopefully, this can be dropped in future chrome versions
    document.activeElement?.blur();

    this.modal.show(BookmarkModal, {
      model: {
        bookmark: new BookmarkFormData(
          this.message.bookmark ||
            Bookmark.createFor(
              this.currentUser,
              "Chat::Message",
              this.message.id
            )
        ),
        afterSave: (bookmarkFormData) => {
          const bookmark = Bookmark.create(bookmarkFormData.saveData);
          this.message.bookmark = bookmark;
          this.appEvents.trigger(
            "bookmarks:changed",
            bookmarkFormData.saveData,
            bookmark.attachedTo()
          );
        },
        afterDelete: () => {
          this.message.bookmark = null;
        },
      },
    });
  }

  @action
  flag() {
    const model = new ChatMessage(this.message.channel, this.message);
    model.username = this.message.user?.username;
    model.user_id = this.message.user?.id;
    this.modal.show(FlagModal, {
      model: {
        flagTarget: new ChatMessageFlag(getOwner(this)),
        flagModel: model,
        setHidden: () => model.set("hidden", true),
      },
    });
  }

  @action
  delete() {
    return this.chatApi
      .trashMessage(this.message.channel.id, this.message.id)
      .catch(popupAjaxError);
  }

  @action
  restore() {
    return this.chatApi
      .restoreMessage(this.message.channel.id, this.message.id)
      .catch(popupAjaxError);
  }

  @action
  rebake() {
    return this.chatApi
      .rebakeMessage(this.message.channel.id, this.message.id)
      .catch(popupAjaxError);
  }

  @action
  reply() {
    this.composer.replyTo(this.message);
  }

  @action
  edit() {
    this.composer.edit(this.message);
  }

  @action
  async openEmojiPicker(trigger) {
    this.interactedChatMessage.emojiPickerOpen = true;

    await this.menu.show(trigger, {
      identifier: "emoji-picker",
      groupIdentifier: "emoji-picker",
      component: EmojiPickerDetached,
      onClose: () => {
        this.interactedChatMessage.emojiPickerOpen = false;
      },
      data: {
        context: `channel_${this.message.channel.id}`,
        didSelectEmoji: (emoji) => {
          this.selectReaction(emoji);
        },
      },
    });
  }

  @action
  async closeEmojiPicker() {
    await this.menu.close("emoji-picker");
    this.interactedChatMessage.emojiPickerOpen = false;
  }

  @bind
  selectReaction(emoji) {
    if (!this.chat.userCanInteractWithChat) {
      return;
    }

    this.react(emoji, REACTIONS.add);
  }

  @action
  handleSecondaryActions(id) {
    this[id](this.message);
  }
}
