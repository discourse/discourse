import { getOwner } from "@ember/application";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { inject as service } from "@ember/service";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";
import { dependentKeyCompat } from "@ember/object/compat";
import { tracked } from "@glimmer/tracking";
import { calculateFilterMode } from "discourse/lib/filter-mode";

export default class NavigationCategory extends Component {
  @service router;
  @service composer;
  @service currentUser;

  @tracked category;
  @tracked filterType;
  @tracked noSubcategories;

  get discovery() {
    return getOwner(this).lookup("controller:discovery");
  }

  @discourseComputed("router.currentRoute.queryParams.f")
  skipCategoriesNavItem(filterParamValue) {
    return filterParamValue === TRACKED_QUERY_PARAM_VALUE;
  }

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
