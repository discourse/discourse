import { click, fillIn } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";

class EmojiPicker {
  constructor(selector) {
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  async fill(input) {
    await fillIn(query(".filter-input", this.element), input);
  }

  async select(emoji) {
    await click(
      `.emoji-picker__scrollable-content img.emoji[data-emoji="${emoji}"]`
    );
  }

  async tone(level) {
    await click(query(".emoji-picker__diversity-trigger", this.element));

    if (level === 1) {
      await click(
        `.emoji-picker__diversity-menu .emoji-picker__diversity-item:not([data-level])`
      );
    } else {
      await click(`.emoji-picker__diversity-menu [data-level="${level}"]`);
    }
  }
}

export default function picker(selector = ".emoji-picker-content") {
  const helper = new EmojiPicker(selector);

  return {
    async fill(input) {
      await helper.fill(input);
    },
    async tone(level) {
      await helper.tone(level);
    },
    async select(emoji) {
      await helper.select(emoji);
    },
  };
}
