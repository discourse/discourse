import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import { isTesting } from "discourse-common/config/environment";
import { clipboardCopy } from "discourse/lib/utilities";
import { REACTIONS } from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatMessageActions {
  livePanel = null;
  currentUser = null;

  constructor(livePanel, currentUser) {
    this.livePanel = livePanel;
    this.currentUser = currentUser;
  }

  copyLink(message) {
    const { protocol, host } = window.location;
    let url = getURL(`/chat/c/-/${message.chat_channel_id}/${message.id}`);
    url = url.indexOf("/") === 0 ? protocol + "//" + host + url : url;
    clipboardCopy(url);
  }

  selectMessage(message, checked) {
    message.set("selected", checked);
    this.livePanel.onSelectMessage(message);
  }

  bulkSelectMessages(message, checked) {
    const lastSelectedIndex = this.#findIndexOfMessage(
      this.livePanel.lastSelectedMessage
    );
    const newlySelectedIndex = this.#findIndexOfMessage(message);
    const sortedIndices = [lastSelectedIndex, newlySelectedIndex].sort(
      (a, b) => a - b
    );

    for (let i = sortedIndices[0]; i <= sortedIndices[1]; i++) {
      this.livePanel.messages[i].set("selected", checked);
    }
  }

  @bind
  react(message, emoji, reactAction) {
    if (
      !this.livePanel.canInteractWithChat ||
      message.loadingReactions.includes(emoji)
    ) {
      return;
    }

    if (this.livePanel.capabilities.canVibrate && !isTesting()) {
      navigator.vibrate(5);
    }

    if (this.livePanel.site.mobileView) {
      this.livePanel.hoverMessage(null);
    }

    message.loadingReactions.push(emoji);
    message.updateReactionsList(emoji, reactAction, this.currentUser, true);

    if (reactAction === REACTIONS.add) {
      this.livePanel.chatEmojiReactionStore.track(`:${emoji}:`);
    }

    return message
      .publishReaction(emoji, reactAction)
      .then(() => {
        this.livePanel.onReactMessage();
      })
      .catch(() => {
        message.updateReactionsList(
          emoji,
          REACTIONS.remove,
          this.currentUser,
          true
        );
      });
  }

  #findIndexOfMessage(message) {
    return this.livePanel.messages.findIndex((m) => m.id === message.id);
  }
}
