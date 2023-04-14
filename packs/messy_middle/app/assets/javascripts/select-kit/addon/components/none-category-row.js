import CategoryRowComponent from "select-kit/components/category-row";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import discourseComputed from "discourse-common/utils/decorators";
import layout from "select-kit/templates/components/category-row";
import { htmlSafe } from "@ember/template";

export default CategoryRowComponent.extend({
  layout,
  classNames: "none category-row",

  @discourseComputed("category")
  badgeForCategory(category) {
    return htmlSafe(
      categoryBadgeHTML(category, {
        link: this.categoryLink,
        allowUncategorized: true,
        hideParent: true,
      })
    );
  },
});
