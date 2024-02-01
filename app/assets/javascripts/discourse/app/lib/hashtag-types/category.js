import { inject as service } from "@ember/service";
import HashtagTypeBase from "./base";

export default class CategoryHashtagType extends HashtagTypeBase {
  @service site;

  constructor() {
    super(...arguments);
    this.loadingIds = new Set();
  }

  get type() {
    return "category";
  }

  get preloadedData() {
    return this.site.categories || [];
  }

  generateColorCssClasses(categoryOrHashtag) {
    let color, parentColor;
    if (categoryOrHashtag.colors) {
      if (categoryOrHashtag.colors.length === 1) {
        color = categoryOrHashtag.colors[0];
      } else {
        parentColor = categoryOrHashtag.colors[0];
        color = categoryOrHashtag.colors[1];
      }
    } else {
      color = categoryOrHashtag.color;
      if (categoryOrHashtag.parentCategory) {
        parentColor = categoryOrHashtag.parentCategory.color;
      }
    }

    let style;
    if (parentColor) {
      style = `background: linear-gradient(-90deg, #${color} 50%, #${parentColor} 50%);`;
    } else {
      style = `background-color: #${color};`;
    }

    return [`.hashtag-color--category-${categoryOrHashtag.id} { ${style} }`];
  }

  generateIconHTML(hashtag) {
    if (!this.registeredIds.has(parseInt(hashtag.id, 10))) {
      if (hashtag.colors) {
        this.registerCss(hashtag);
      } else {
        this.load(hashtag.id);
      }
    }

    const colorCssClass = `hashtag-color--${this.type}-${hashtag.id}`;
    return `<span class="hashtag-category-badge ${colorCssClass}"></span>`;
  }
}
