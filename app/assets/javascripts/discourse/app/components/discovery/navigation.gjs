import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ReorderCategories from "discourse/components/modal/reorder-categories";
import { calculateFilterMode } from "discourse/lib/filter-mode";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";

export default class DiscoveryNavigation extends Component {
  @service router;
  @service currentUser;
  @service modal;

  get filterMode() {
    return calculateFilterMode({
      category: this.args.category,
      filterType: this.args.filterType,
      noSubcategories: this.args.noSubcategories,
    });
  }

  get skipCategoriesNavItem() {
    return this.router.currentRoute.queryParams.f === TRACKED_QUERY_PARAM_VALUE;
  }

  get canCreateTopic() {
    return this.currentUser?.can_create_topic;
  }

  get bodyClass() {
    if (this.args.tag) {
      return [
        "tags-page",
        this.args.additionalTags ? "tags-intersection" : null,
      ]
        .filter(Boolean)
        .join(" ");
    } else if (this.filterMode === "categories") {
      return "navigation-categories";
    } else if (this.args.category) {
      return "navigation-category";
    } else {
      return "navigation-topics";
    }
  }

  @action
  editCategory() {
    DiscourseURL.routeTo(`/c/${Category.slugFor(this.args.category)}/edit`);
  }

  @action
  createCategory() {
    this.router.transitionTo("newCategory");
  }

  @action
  reorderCategories() {
    this.modal.show(ReorderCategories);
  }
}
