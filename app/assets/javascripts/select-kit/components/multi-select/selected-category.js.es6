import SelectedNameComponent from "select-kit/components/multi-select/selected-name";
import computed from "ember-addons/ember-computed-decorators";
import { categoryBadgeHTML } from "discourse/helpers/category-link";

export default SelectedNameComponent.extend({
  classNames: "selected-category",
  layoutName: "select-kit/templates/components/multi-select/selected-category",

  @computed("computedContent.originalContent")
  badge(category) {
    return categoryBadgeHTML(category, {
      allowUncategorized: true,
      link: false
    }).htmlSafe();
  }
});
