import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";

//  A breadcrumb including category drop downs
export default Component.extend({
  classNameBindings: ["hidden:hidden", ":category-breadcrumb"],
  tagName: "ol",

  parentCategory: Ember.computed.alias("category.parentCategory"),

  parentCategories: Ember.computed.filter("categories", function(c) {
    if (
      c.id === this.site.get("uncategorized_category_id") &&
      !this.siteSettings.allow_uncategorized_topics
    ) {
      // Don't show "uncategorized" if allow_uncategorized_topics setting is false.
      return false;
    }

    return !c.get("parentCategory");
  }),

  @computed("parentCategories")
  parentCategoriesSorted(parentCategories) {
    if (this.siteSettings.fixed_category_positions) {
      return parentCategories;
    }

    return parentCategories.sortBy("totalTopicCount").reverse();
  },

  @computed("category")
  hidden(category) {
    return this.site.mobileView && !category;
  },

  firstCategory: Ember.computed.or("{parentCategory,category}"),

  @computed("category", "parentCategory")
  secondCategory(category, parentCategory) {
    if (parentCategory) return category;
    return null;
  },

  @computed("firstCategory", "hideSubcategories")
  childCategories(firstCategory, hideSubcategories) {
    if (hideSubcategories) {
      return [];
    }

    if (!firstCategory) {
      return [];
    }

    return this.categories.filter(
      c => c.get("parentCategory") === firstCategory
    );
  }
});
