import { and, none } from "@ember/object/computed";
import FilterModeMixin from "discourse/mixins/filter-mode";
import { getOwner } from "@ember/application";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { inject as service } from "@ember/service";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";

export default class CategoryNavigation extends Component.extend(
  FilterModeMixin
) {
  @service router;

  @none("category.parentCategory") showingParentCategory;

  @and("category.show_subcategory_list", "showingParentCategory")
  showingSubcategoryList;

  get discovery() {
    return getOwner(this).lookup("controller:discovery");
  }

  @discourseComputed("router.currentRoute.queryParams.f")
  skipCategoriesNavItem(filterParamValue) {
    return filterParamValue === TRACKED_QUERY_PARAM_VALUE;
  }
}
