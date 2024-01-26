import { inject as service } from "@ember/service";
import HashtagTypeBase from "./base";

export default class CategoryHashtagType extends HashtagTypeBase {
  @service site;

  get type() {
    return "category";
  }

  get preloadedData() {
    return this.site.categories || [];
  }

  generateColorCssClasses() {
    // We rely on default CSS styling
    return [];
  }

  generateIconHTML(hashtag) {
    if (hashtag.colors?.length) {
      let style =
        hashtag.colors.length === 1
          ? `--category-badge-color: #${hashtag.colors[0]}`
          : `--parent-category-badge-color: #${hashtag.colors[0]}; --category-badge-color: #${hashtag.colors[1]}`;
      return `<span class="hashtag-category-badge badge-category" style="${style}"></span>`;
    } else {
      return `<span class="hashtag-category-badge badge-category" data-category-id="${hashtag.id}"></span>`;
    }
  }
}
