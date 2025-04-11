import { service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { iconHTML } from "discourse/lib/icon-library";
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
    if (parentColor) {
      style = `background: linear-gradient(-90deg, #${color} 50%, #${parentColor} 50%);`;
    } else if (categoryOrHashtag.styleType === "icon") {
      style = `color: #${color};`;
    } else if (categoryOrHashtag.styleType === "square") {
      style = `background-color: #${color};`;
    } else {
      return [];
    }

    return [`.hashtag-color--category-${categoryOrHashtag.id} { ${style} }`];
  }

  generateIconHTML(hashtag) {
    hashtag.preloaded ? this.onLoad(hashtag) : this.load(hashtag.id);
    let style = "";

    if (hashtag.style_type === "icon" && hashtag.icon) {
      style = iconHTML(hashtag.icon);
    }
    if (hashtag.style_type === "emoji" && hashtag.emoji) {
      style = replaceEmoji(`:${hashtag.emoji}:`);
    }

    const colorCssClass = `hashtag-color--${this.type}-${hashtag.id}`;
    return `<span class="hashtag-category-${hashtag.style_type} ${colorCssClass}">${style}</span>`;
  }

  isLoaded(id) {
    return !this.site.lazy_load_categories || super.isLoaded(id);
  }
}
