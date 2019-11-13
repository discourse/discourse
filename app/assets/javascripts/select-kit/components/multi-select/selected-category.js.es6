import SelectedNameComponent from "select-kit/components/multi-select/selected-name";
import discourseComputed from "discourse-common/utils/decorators";
import { categoryBadgeHTML } from "discourse/helpers/category-link";

export default SelectedNameComponent.extend({
  classNames: "selected-category",
  layoutName: "select-kit/templates/components/multi-select/selected-category",

  @discourseComputed("computedContent.originalContent")
  badge(category) {
    return categoryBadgeHTML(category, {
      allowUncategorized: true,
      link: false
    }).htmlSafe();
  }
});
