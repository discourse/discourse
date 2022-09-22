import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import CategorySectionLink from "discourse/lib/sidebar/user/categories-section/category-section-link";
import { canDisplayCategory } from "discourse/lib/sidebar/helpers";

export default class SidebarAnonymousCategoriesSection extends Component {
  @service topicTrackingState;
  @service site;
  @service siteSettings;

  @cached
  get sectionLinks() {
    let categories = this.site.categoriesList;

    if (this.siteSettings.default_sidebar_categories) {
      const defaultCategoryIds = this.siteSettings.default_sidebar_categories
        .split("|")
        .map((categoryId) => parseInt(categoryId, 10));

      categories = categories.filter((category) =>
        defaultCategoryIds.includes(category.id)
      );
    } else {
      categories = categories
        .filter(
          (category) =>
            canDisplayCategory(category, this.siteSettings) &&
            !category.parent_category_id
        )
        .slice(0, 5);
    }

    return categories.map((category) => {
      return new CategorySectionLink({
        category,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }
}
