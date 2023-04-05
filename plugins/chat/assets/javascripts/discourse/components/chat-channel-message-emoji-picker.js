import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { headerOffset } from "discourse/lib/offset-calculator";
import { createPopper } from "@popperjs/core";

export default class ChatChannelMessageEmojiPicker extends Component {
  context = "chat-channel-message";

  @service site;
  @service chatEmojiPickerManager;

  @action
  didSelectEmoji(emoji) {
    this.chatEmojiPickerManager.picker?.didSelectEmoji(emoji);
    this.chatEmojiPickerManager.close();
  }

  @action
  didInsert(element) {
    if (this.site.mobileView) {
      element.classList.remove("hidden");
      return;
    }

    this._popper = createPopper(
      this.chatEmojiPickerManager.picker?.trigger,
      element,
      {
        placement: "top",
        modifiers: [
          {
            name: "eventListeners",
            options: { scroll: false, resize: false },
          },
          {
            name: "flip",
            options: { padding: { top: headerOffset() } },
          },
        ],
      }
    );

    element.classList.remove("hidden");
  }

  @action
  willDestroy() {
    this._popper?.destroy();
  }
}
