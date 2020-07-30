import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  showMuted: false,
  noCategoryStyle: equal("siteSettings.category_style", "none"),

  @discourseComputed("showMutedCategories", "filteredCategories")
  mutedToggleIcon(showMutedCategories, filteredCategories) {
    if (filteredCategories.length === 0) {
      return;
    }

    if (showMutedCategories) return "minus";

    return "plus";
  },

  @discourseComputed("showMuted", "filteredCategories")
  showMutedCategories(showMuted, filteredCategories) {
    return showMuted || filteredCategories.length === 0;
  },

  @discourseComputed("categories")
  filteredCategories(categories) {
    if (!categories || categories.length === 0) {
      return [];
    }

    return categories.filter(cat => !cat.isHidden);
  },

  @discourseComputed("categories")
  mutedCategories(categories) {
    if (!categories || categories.length === 0) {
      return [];
    }

    // hide in single category pages
    if (categories.firstObject.parent_category_id) {
      return [];
    }

    return categories.filterBy("hasMuted");
  },

  @action
  toggleShowMuted() {
    this.toggleProperty("showMuted");
  }
});
