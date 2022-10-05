import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";

export default Component.extend({
  tagName: "",
  showMuted: false,
  noCategoryStyle: equal("siteSettings.category_style", "none"),

  @discourseComputed("showMutedCategories", "filteredCategories.length")
  mutedToggleIcon(showMutedCategories, filteredCategoriesLength) {
    if (filteredCategoriesLength === 0) {
      return;
    }

    if (showMutedCategories) {
      return "minus";
    }

    return "plus";
  },

  @discourseComputed("showMuted", "filteredCategories.length")
  showMutedCategories(showMuted, filteredCategoriesLength) {
    return showMuted || filteredCategoriesLength === 0;
  },

  @discourseComputed("categories", "categories.length")
  filteredCategories(categories, categoriesLength) {
    if (!categories || categoriesLength === 0) {
      return [];
    }

    return categories.filter((cat) => !cat.isHidden);
  },

  @discourseComputed("categories", "categories.length")
  mutedCategories(categories, categoriesLength) {
    if (!categories || categoriesLength === 0) {
      return [];
    }

    // hide in single category pages
    if (categories.firstObject.parent_category_id) {
      return [];
    }

    return categories.filterBy("hasMuted");
  },

  @action
  toggleShowMuted(event) {
    event?.preventDefault();
    this.toggleProperty("showMuted");
  },
});
