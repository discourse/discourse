import CategoryRowComponent from "select-kit/components/category-row";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import computed from "ember-addons/ember-computed-decorators";

export default CategoryRowComponent.extend({
  layoutName: "select-kit/templates/components/category-row",
  classNames: "none category-row",

  @computed("category")
  badgeForCategory(category) {
    return categoryBadgeHTML(category, {
      link: this.get("categoryLink"),
      allowUncategorized: true,
      hideParent: true
    }).htmlSafe();
  }
});
