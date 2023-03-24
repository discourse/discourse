import getURL from "discourse-common/lib/get-url";
import showModal from "discourse/lib/show-modal";
import ChatMessageFlag from "discourse/plugins/chat/discourse/lib/chat-message-flag";
import Bookmark from "discourse/models/bookmark";
import { openBookmarkModal } from "discourse/controllers/bookmark";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { clipboardCopy } from "discourse/lib/utilities";
import { REACTIONS } from "discourse/plugins/chat/discourse/models/chat-message-reaction";
import { setOwner } from "@ember/application";

export default class ChatMessageActions {
  @service appEvents;
  @service dialog;
  @service chat;
  @service chatEmojiReactionStore;
  @service chatApi;

  livePanel = null;
  currentUser = null;

  constructor(owner, livePanel, currentUser) {
    setOwner(this, owner);
    this.livePanel = livePanel;
    this.currentUser = currentUser;
  }

  select(message, checked = true) {
    message.selected = checked;
    this.livePanel.onSelectMessage(message);
  }

  bulkSelect(message, checked) {
    const lastSelectedIndex = this.livePanel.findIndexOfMessage(
      this.livePanel.lastSelectedMessage
    );
    const newlySelectedIndex = this.livePanel.findIndexOfMessage(message);
    const sortedIndices = [lastSelectedIndex, newlySelectedIndex].sort(
      (a, b) => a - b
    );

    for (let i = sortedIndices[0]; i <= sortedIndices[1]; i++) {
      this.livePanel.messages[i].selected = checked;
    }
  }

  copyLink(message) {
    const { protocol, host } = window.location;
    let url = getURL(`/chat/c/-/${message.channelId}/${message.id}`);
    url = url.indexOf("/") === 0 ? protocol + "//" + host + url : url;
    clipboardCopy(url);
  }

  @action
  react(message, emoji, reactAction) {
    if (!this.chat.userCanInteractWithChat) {
      return;
    }

    if (this.livePanel.reacting) {
      return;
    }

    if (this.livePanel.capabilities.canVibrate && !isTesting()) {
      navigator.vibrate(5);
    }

    if (this.livePanel.site.mobileView) {
      this.livePanel.hoverMessage(null);
    }

    if (reactAction === REACTIONS.add) {
      this.chatEmojiReactionStore.track(`:${emoji}:`);
    }

    this.livePanel.reacting = true;

    message.react(emoji, reactAction, this.currentUser, this.currentUser.id);

    return this.chatApi
      .publishReaction(message.channelId, message.id, emoji, reactAction)
      .then(() => {
        this.livePanel.onReactMessage();
      })
      .catch((errResult) => {
        popupAjaxError(errResult);
        message.react(
          emoji,
          REACTIONS.remove,
          this.currentUser,
          this.currentUser.id
        );
      })
      .finally(() => {
        this.livePanel.reacting = false;
      });
  }

  @action
  toggleBookmark(message) {
    return openBookmarkModal(
      message.bookmark ||
        Bookmark.createFor(this.currentUser, "Chat::Message", message.id),
      {
        onAfterSave: (savedData) => {
          const bookmark = Bookmark.create(savedData);
          message.bookmark = bookmark;
          this.appEvents.trigger(
            "bookmarks:changed",
            savedData,
            bookmark.attachedTo()
          );
        },
        onAfterDelete: () => {
          message.bookmark = null;
        },
      }
    );
  }

  @action
  flag(message) {
    const model = message;
    model.username = message.user?.username;
    model.user_id = message.user?.id;
    const controller = showModal("flag", { model });
    controller.set("flagTarget", new ChatMessageFlag());
  }

  @action
  delete(message) {
    return this.chatApi
      .deleteMessage(message.channelId, message.id)
      .catch(popupAjaxError);
  }

  @action
  restore(message) {
    return this.chatApi
      .restoreMessage(message.channelId, message.id)
      .catch(popupAjaxError);
  }

  @action
  rebake(message) {
    return this.chatApi
      .rebakeMessage(message.channelId, message.id)
      .catch(popupAjaxError);
  }

  @action
  reply(message) {
    this.livePanel.composerService.setReplyTo(message.id);
  }

  @action
  edit(message) {
    this.livePanel.composerService.editButtonClicked(message.id);
  }

  @action
  openThread(message) {
    this.livePanel.router.transitionTo("chat.channel.thread", message.threadId);
  }
}
