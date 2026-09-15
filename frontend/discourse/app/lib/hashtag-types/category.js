import { service } from "@ember/service";
import { iconHTML } from "discourse/lib/icon-library";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import HashtagTypeBase from "./base";

export default class CategoryHashtagType extends HashtagTypeBase {
  @service site;

  get type() {
    return "category";
  }

  get preloadedData() {
    return this.site.categories || [];
  }

  generatePreloadedCssClasses() {
    return [
      // Set a default color for category hashtags. This is added here instead
      // of `hashtag.scss` because of the CSS precedence rules (<link> has a
      // higher precedence than <style>)
      ".hashtag-category-square { background-color: var(--primary-medium); }",
      ...super.generatePreloadedCssClasses(),
    ];
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
      if (
        categoryOrHashtag.parentCategory &&
        categoryOrHashtag.styleType === "square"
      ) {
        parentColor = categoryOrHashtag.parentCategory.color;
      }
    }

    let style;
    if (categoryOrHashtag.style_type === "square") {
      if (parentColor) {
        style = `background: linear-gradient(-90deg, #${color} 50%, #${parentColor} 50%);`;
      } else {
        style = `background-color: #${color};`;
      }
    } else if (categoryOrHashtag.style_type === "icon") {
      style = `color: #${color};`;
    } else {
      return [];
    }

    return [`.hashtag-color--category-${categoryOrHashtag.id} { ${style} }`];
  }

  generateIconHTML(hashtag) {
    hashtag.preloaded ? this.onLoad(hashtag) : this.load(hashtag.id);
    const styleType = ["square", "icon", "emoji"].includes(hashtag.style_type)
      ? hashtag.style_type
      : "square";
    const hashtagId = Number.parseInt(hashtag.id, 10);
    let style = "";

    if (styleType === "icon" && hashtag.icon) {
      style = iconHTML(hashtag.icon);
    }
    if (styleType === "emoji" && hashtag.emoji) {
      style = dReplaceEmoji(`:${hashtag.emoji}:`);
    }

    const colorCssClass = `hashtag-color--${this.type}-${hashtagId}`;
    return `<span class="hashtag-category-${styleType} ${colorCssClass}">${style}</span>`;
  }

  isLoaded(id) {
    return !this.site.lazy_load_categories || super.isLoaded(id);
  }
}
