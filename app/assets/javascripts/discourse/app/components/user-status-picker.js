import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

export default class UserStatusPicker extends Component {
  tagName = "";
  isFocused = false;
  emojiPickerIsActive = false;

  didInsertElement() {
    this._super(...arguments);

    if (!this.status) {
      this.set("status", {});
    }
  }

  @computed("status.emoji")
  get emojiHtml() {
    const emoji = escapeExpression(`:${this.status.emoji}:`);
    return emojiUnescape(emoji);
  }

  @action
  blur() {
    this.set("isFocused", false);
  }

  @action
  emojiSelected(emoji) {
    this.set("status.emoji", emoji);
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
    if (!this.status.emoji) {
      this.set("status.emoji", "speech_balloon");
    }
  }

  @action
  toggleEmojiPicker(event) {
    event.stopPropagation();
    this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
  }
}
