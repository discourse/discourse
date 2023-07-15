import Component from "@ember/component";
import FilterModeMixin from "discourse/mixins/filter-mode";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";

export default class DefaultNavigation extends Component.extend(
  FilterModeMixin
) {
  @service router;

  @discourseComputed("router.currentRoute.queryParams.f")
  skipCategoriesNavItem(filterParamValue) {
    return filterParamValue === TRACKED_QUERY_PARAM_VALUE;
  }
}
