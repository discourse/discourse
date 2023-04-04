import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { headerOffset } from "discourse/lib/offset-calculator";
import { createPopper } from "@popperjs/core";
import { schedule } from "@ember/runloop";

export default class ChatChannelMessageEmojiPicker extends Component {
  context = "chat-channel-message";

  @service chatEmojiPickerManager;

  @action
  didSelectEmoji(emoji) {
    this.chatEmojiPickerManager.picker?.didSelectEmoji(emoji);
  }

  @action
  didInsert(element) {
    this._popper?.destroy();

    schedule("afterRender", () => {
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
    });
  }

  @action
  willDestroy() {
    this._popper?.destroy();
  }
}
