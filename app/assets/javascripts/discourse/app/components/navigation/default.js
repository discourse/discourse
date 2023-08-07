import { inject as service } from "@ember/service";
import Component from "@ember/component";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";
import { calculateFilterMode } from "discourse/lib/filter-mode";
import { tracked } from "@glimmer/tracking";

export default class NavigationDefault extends Component {
  @service router;

  @tracked category;
  @tracked filterType;
  @tracked noSubcategories;

  get filterMode() {
    return calculateFilterMode({
      category: this.category,
      filterType: this.filterType,
      noSubcategories: this.noSubcategories,
    });
  }

  get skipCategoriesNavItem() {
    return this.router.currentRoute.queryParams.f === TRACKED_QUERY_PARAM_VALUE;
  }
}
