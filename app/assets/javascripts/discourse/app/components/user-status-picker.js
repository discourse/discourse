import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

export default class UserStatusPicker extends Component {
  tagName = "";
  isFocused = false;
  emojiPickerIsActive = false;
  emoji = null;
  description = null;

  @computed("emoji")
  get emojiHtml() {
    const emoji = escapeExpression(`:${this.emoji}:`);
    return emojiUnescape(emoji);
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
      document.querySelector(".btn-emoji")?.focus();
    });
  }

  @action
  focus() {
    this.set("isFocused", true);
  }

  @action
  onEmojiPickerOutsideClick() {
    this.set("emojiPickerIsActive", false);
  }

  @action
  setDefaultEmoji() {
    if (!this.emoji) {
      this.set("emoji", "speech_balloon");
    }
  }

  @action
  toggleEmojiPicker(event) {
    event.stopPropagation();
    this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
  }
}
