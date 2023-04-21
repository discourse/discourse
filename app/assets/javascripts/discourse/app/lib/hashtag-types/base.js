import { setOwner } from "@ember/application";
import { iconHTML } from "discourse-common/lib/icon-library";

export default class HashtagTypeBase {
  constructor(container) {
    setOwner(this, container);
  }

  get type() {
    throw "not implemented";
  }

  get preloadedData() {
    throw "not implemented";
  }

  generateColorCssClasses() {
    throw "not implemented";
  }

  generateIconHTML(hashtag) {
    return iconHTML(hashtag.icon, {
      class: `hashtag-color--${this.type}-${hashtag.id}`,
    });
  }
}
