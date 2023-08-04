import { inject as service } from "@ember/service";
import Controller, { inject as controller } from "@ember/controller";
import FilterModeMixin from "discourse/mixins/filter-mode";
import { TRACKED_QUERY_PARAM_VALUE } from "discourse/lib/topic-list-tracked-filter";

export default class DefaultController extends Controller.extend(
  FilterModeMixin
) {
  @service router;
  @controller discovery;

  get skipCategoriesNavItem() {
    return this.router.currentRoute.queryParams.f === TRACKED_QUERY_PARAM_VALUE;
  }
}
