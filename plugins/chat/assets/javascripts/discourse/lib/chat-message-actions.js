import getURL from "discourse-common/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";

export default class ChatMessageActions {
  livePanel = null;

  constructor(livePanel) {
    // now its parent "context" or "scope" needs to
    // be put into the selection mode...we could probably
    // just store a reference to this parent on init?
    //
    // so in live pane and thread panel we would do new
    // ChatMessageActions(this) and call this.livePanel.XX
    this.livePanel = livePanel;
  }

  copyLink(message) {
    const { protocol, host } = window.location;
    let url = getURL(`/chat/c/-/${message.chat_channel_id}/${message.id}`);
    url = url.indexOf("/") === 0 ? protocol + "//" + host + url : url;
    clipboardCopy(url);
  }

  selectMessage(message, checked) {
    message.set("selected", checked);

    // naming for all the parent panel stuff should be
    // the same with on- prefix, e.g. onSelectMessage,
    // onDeleteMessage etc.
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

  #findIndexOfMessage(message) {
    return this.livePanel.messages.findIndex((m) => m.id === message.id);
  }
}
