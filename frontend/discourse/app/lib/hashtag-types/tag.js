import { iconHTML } from "discourse/lib/icon-library";
import HashtagTypeBase from "./base.js";

export default class TagHashtagType extends HashtagTypeBase {
  get type() {
    return "tag";
  }

  /** @returns {import("discourse/models/tag").default[]} */
  get preloadedData() {
    return [];
  }

  /** @returns {string[]} */
  generateColorCssClasses() {
    return [];
  }

  generateIconHTML(hashtag) {
    return iconHTML(hashtag.icon, {
      class: `hashtag-color--${this.type}-${hashtag.id}`,
    });
  }
}
