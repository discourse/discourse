import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import discourseComputed from "discourse-common/utils/decorators";
import CategoryRowComponent from "select-kit/components/category-row";

@classNames("none category-row")
export default class NoneCategoryRow extends CategoryRowComponent {
  @discourseComputed("category")
  badgeForCategory(category) {
    return htmlSafe(
      categoryBadgeHTML(category, {
        link: false,
        allowUncategorized: true,
        hideParent: true,
      })
    );
  }
}
