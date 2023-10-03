import HashtagTypeBase from "./base";
import { iconHTML } from "discourse-common/lib/icon-library";

export default class TagHashtagType extends HashtagTypeBase {
  get type() {
    return "tag";
  }

  get preloadedData() {
    return [];
  }

  generateColorCssClasses() {
    return [];
  }

  generateIconHTML(hashtag) {
    return iconHTML(hashtag.icon, {
      class: `hashtag-color--${this.type}-${hashtag.id}`,
    });
  }
}
