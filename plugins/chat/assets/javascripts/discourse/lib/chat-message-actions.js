import getURL from "discourse-common/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";

export default class ChatMessageActions {
  contextualPanel = null;

  constructor(contextualPanel) {
    // now its parent "context" or "scope" needs to
    // be put into the selection mode...we could probably
    // just store a reference to this parent on init?
    //
    // so in live pane and thread panel we would do new
    // ChatMessageActions(this) and call this.contextualPanel.XX
    this.contextualPanel = contextualPanel;
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
    this.contextualPanel.onSelectMessage(message);
  }

  bulkSelectMessages(message, checked) {
    const lastSelectedIndex = this.#findIndexOfMessage(
      this.contextualPanel.lastSelectedMessage
    );
    const newlySelectedIndex = this.#findIndexOfMessage(message);
    const sortedIndices = [lastSelectedIndex, newlySelectedIndex].sort(
      (a, b) => a - b
    );

    for (let i = sortedIndices[0]; i <= sortedIndices[1]; i++) {
      this.messages[i].set("selected", checked);
    }
  }

  #findIndexOfMessage(message) {
    return this.messages.findIndex((m) => m.id === message.id);
  }
}
