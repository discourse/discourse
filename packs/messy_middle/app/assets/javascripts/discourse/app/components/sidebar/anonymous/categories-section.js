import { canDisplayCategory } from "discourse/lib/sidebar/helpers";
import SidebarCommonCategoriesSection from "discourse/components/sidebar/common/categories-section";
import Category from "discourse/models/category";

export default class SidebarAnonymousCategoriesSection extends SidebarCommonCategoriesSection {
  constructor() {
    super(...arguments);

    if (!this.siteSettings.default_sidebar_categories) {
      this.shouldSortCategoriesByDefault = false;
    }
  }

  get categories() {
    if (this.siteSettings.default_sidebar_categories) {
      return Category.findByIds(
        this.siteSettings.default_sidebar_categories
          .split("|")
          .map((categoryId) => parseInt(categoryId, 10))
      );
    } else {
      return this.site.categoriesList
        .filter((category) => {
          return (
            !category.parent_category_id &&
            canDisplayCategory(category.id, this.siteSettings)
          );
        })
        .slice(0, 5);
    }
  }
}
