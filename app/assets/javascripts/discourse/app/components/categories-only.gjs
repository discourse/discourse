import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class CategoriesOnly extends Component {
  showMuted = false;

  @discourseComputed("showMutedCategories", "filteredCategories.length")
  mutedToggleIcon(showMutedCategories, filteredCategoriesLength) {
    if (filteredCategoriesLength === 0) {
      return;
    }

    if (showMutedCategories) {
      return "minus";
    }

    return "plus";
  }

  @discourseComputed("showMuted", "filteredCategories.length")
  showMutedCategories(showMuted, filteredCategoriesLength) {
    return showMuted || filteredCategoriesLength === 0;
  }

  @discourseComputed("categories", "categories.length")
  filteredCategories(categories, categoriesLength) {
    if (!categories || categoriesLength === 0) {
      return [];
    }

    return categories.filter((cat) => !cat.isHidden);
  }

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
  }

  @action
  toggleShowMuted(event) {
    event?.preventDefault();
    this.toggleProperty("showMuted");
  }
}
