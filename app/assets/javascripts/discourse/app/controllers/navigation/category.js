import NavigationDefaultController from "discourse/controllers/navigation/default";
import { calculateFilterMode } from "discourse/lib/filter-mode";
import { dependentKeyCompat } from "@ember/object/compat";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class NavigationCategoryController extends NavigationDefaultController {
  @service composer;

  @tracked category;
  @tracked filterType;
  @tracked noSubcategories;

  @dependentKeyCompat
  get filterMode() {
    return calculateFilterMode({
      category: this.category,
      filterType: this.filterType,
      noSubcategories: this.noSubcategories,
    });
  }

  get createTopicTargetCategory() {
    if (this.category?.canCreateTopic) {
      return this.category;
    }

    if (this.siteSettings.default_subcategory_on_read_only_category) {
      return this.category?.subcategoryWithCreateTopicPermission;
    }
  }

  get enableCreateTopicButton() {
    return !!this.createTopicTargetCategory;
  }

  get canCreateTopic() {
    return this.currentUser?.can_create_topic;
  }
}
