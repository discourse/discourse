import { inject as service } from "@ember/service";
import Component from "@ember/component";
import FilterModeMixin from "discourse/mixins/filter-mode";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";

export default class DefaultNavigation extends Component.extend(
  FilterModeMixin
) {
  @service router;

  get skipCategoriesNavItem() {
    return this.router.currentRoute.queryParams.f === TRACKED_QUERY_PARAM_VALUE;
  }
}
