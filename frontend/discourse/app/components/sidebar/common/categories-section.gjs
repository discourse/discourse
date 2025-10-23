import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { canDisplayCategory } from "discourse/lib/sidebar/helpers";
import CategorySectionLink from "discourse/lib/sidebar/user/categories-section/category-section-link";
import Category from "discourse/models/category";

export const TOP_SITE_CATEGORIES_TO_SHOW = 5;

export default class SidebarCommonCategoriesSection extends Component {
  @service site;
  @service siteSettings;
  @service topicTrackingState;

  shouldSortCategoriesByDefault = true;

  /**
   * Override in child
   *
   * @returns {Object[]} An array of Category objects
   */
  get categories() {}

  get topSiteCategories() {
    return this.site.categoriesList
      .filter((category) => {
        return (
          !category.parent_category_id &&
          canDisplayCategory(category.id, this.siteSettings)
        );
      })
      .slice(0, TOP_SITE_CATEGORIES_TO_SHOW);
  }

  get sortedCategories() {
    if (!this.shouldSortCategoriesByDefault) {
      return this.categories;
    }

    let categories = [...this.site.categories];

    if (!this.siteSettings.fixed_category_positions) {
      categories.sort((a, b) => a.name.localeCompare(b.name));
    }

    const categoryIds = this.categories.map((category) => category.id);

    return Category.sortCategories(categories).reduce(
      (filteredCategories, category) => {
        if (
          categoryIds.includes(category.id) &&
          canDisplayCategory(category.id, this.siteSettings)
        ) {
          filteredCategories.push(category);
        }

        return filteredCategories;
      },
      []
    );
  }

  @cached
  get sectionLinks() {
    return this.sortedCategories.map((category) => {
      return new CategorySectionLink({
        category,
        topicTrackingState: this.topicTrackingState,
        currentUser: this.currentUser,
      });
    });
  }
}
