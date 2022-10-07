import { inject as service } from "@ember/service";
import { canDisplayCategory } from "discourse/lib/sidebar/helpers";
import SidebarCommonCategoriesSection from "discourse/components/sidebar/common/categories-section";

export default class SidebarAnonymousCategoriesSection extends SidebarCommonCategoriesSection {
  @service site;

  get categories() {
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

    return categories;
  }
}
