import HashtagTypeBase from "./base";
import { inject as service } from "@ember/service";

export default class CategoryHashtagType extends HashtagTypeBase {
  @service site;

  get type() {
    return "category";
  }

  get preloadedData() {
    return this.site.categories || [];
  }

  generateColorCssClasses(model) {
    const generatedCssClasses = [];
    const backgroundGradient = [`var(--category-${model.id}-color) 50%`];
    if (model.parentCategory) {
      backgroundGradient.push(
        `var(--category-${model.parentCategory.id}-color) 50%`
      );
    } else {
      backgroundGradient.push(`var(--category-${model.id}-color) 50%`);
    }

    generatedCssClasses.push(`.hashtag-color--category-${model.id} {
  background: linear-gradient(90deg, ${backgroundGradient.join(", ")});
}`);

    return generatedCssClasses;
  }

  generateIconHTML(hashtag) {
    return `<span class="hashtag-category-badge hashtag-color--${this.type}-${hashtag.id}"></span>`;
  }
}
