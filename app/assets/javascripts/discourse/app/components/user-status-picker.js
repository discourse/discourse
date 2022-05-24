import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { emojiUnescape } from "discourse/lib/text";

export default class UserStatusPicker extends Component {
  isFocused = false;
  emojiPickerIsActive = false;
  emoji = null;
  description = null;

  @computed("emoji")
  get emojiHtml() {
    return emojiUnescape(`:${this.emoji}:`);
  }

  @action
  blur() {
    this.set("isFocused", false);
  }

  @action
  emojiSelected(emoji) {
    this.set("emoji", emoji);
    this.set("emojiPickerIsActive", false);

    scheduleOnce("afterRender", () => {
      document.querySelector(".btn-emoji").focus();
    });
  }

  @action
  focus() {
    this.set("isFocused", true);
  }

  @action
  setDefaultEmoji() {
    if (!this.emoji) {
      this.set("emoji", "mega");
    }
  }

  @action
  toggleEmojiPicker() {
    this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
  }
}
