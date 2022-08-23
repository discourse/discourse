import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import Component from "@glimmer/component";
import CategorySectionLink from "discourse/lib/sidebar/categories-section/category-section-link";

export default class SidebarAnonymousCategoriesSection extends Component {
  @service topicTrackingState;
  @service site;
  @service siteSettings;

  @cached
  get sectionLinks() {
    let categories = this.site.categories;

    if (this.siteSettings.default_sidebar_categories) {
      const defaultCategoryIds = this.siteSettings.default_sidebar_categories
        .split("|")
        .map((categoryId) => parseInt(categoryId, 10));

      categories = categories.filter((category) =>
        defaultCategoryIds.includes(category.id)
      );
    } else {
      categories = categories
        .filter((category) => !category.parent_category_id)
        .slice(0, 5);
    }

    return categories.map((category) => {
      return new CategorySectionLink({
        category,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }

  get moreLink() {
    return {
      name: "more-categories",
      text: I18n.t("sidebar.more"),
      route: "discovery.categories",
    };
  }
}
