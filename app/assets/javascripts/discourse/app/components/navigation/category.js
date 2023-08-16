import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";
import { calculateFilterMode } from "discourse/lib/filter-mode";
import { action } from "@ember/object";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";

export default class NavigationCategory extends Component {
  @service router;
  @service composer;
  @service currentUser;

  get skipCategoriesNavItem() {
    return (
      this.router.currentRoute.queryParams?.f === TRACKED_QUERY_PARAM_VALUE
    );
  }

  get filterMode() {
    return calculateFilterMode({
      category: this.args.category,
      filterType: this.args.filterType,
      noSubcategories: this.args.noSubcategories,
    });
  }

  get createTopicTargetCategory() {
    if (this.args.category?.canCreateTopic) {
      return this.args.category;
    }

    if (this.siteSettings.default_subcategory_on_read_only_category) {
      return this.args.category?.subcategoryWithCreateTopicPermission;
    }
  }

  get enableCreateTopicButton() {
    return !!this.createTopicTargetCategory;
  }

  get canCreateTopic() {
    return this.currentUser?.can_create_topic;
  }

  @action
  editCategory() {
    DiscourseURL.routeTo(`/c/${Category.slugFor(this.args.category)}/edit`);
  }
}
