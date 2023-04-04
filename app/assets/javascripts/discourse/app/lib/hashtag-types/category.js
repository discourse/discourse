import HashtagTypeBase from "./base";

export default class CategoryHashtagType extends HashtagTypeBase {
  get type() {
    return "category";
  }

  get preloadedData() {
    return this.container.lookup("service:site").categories;
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
}
