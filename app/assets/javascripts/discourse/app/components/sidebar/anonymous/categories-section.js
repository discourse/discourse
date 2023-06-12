import SidebarCommonCategoriesSection from "discourse/components/sidebar/common/categories-section";
import Category from "discourse/models/category";

export default class SidebarAnonymousCategoriesSection extends SidebarCommonCategoriesSection {
  constructor() {
    super(...arguments);

    if (!this.siteSettings.default_navigation_menu_categories) {
      this.shouldSortCategoriesByDefault = false;
    }
  }

  get categories() {
    if (this.siteSettings.default_navigation_menu_categories) {
      return Category.findByIds(
        this.siteSettings.default_navigation_menu_categories
          .split("|")
          .map((categoryId) => parseInt(categoryId, 10))
      );
    } else {
      return this.topSiteCategories;
    }
  }
}
