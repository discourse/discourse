import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";
import { calculateFilterMode } from "discourse/lib/filter-mode";

export default class NavigationDefault extends Component {
  @service router;
  @service currentUser;
  @service composer;

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
}
