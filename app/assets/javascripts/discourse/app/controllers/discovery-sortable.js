import Controller, { inject as controller } from "@ember/controller";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import discourseComputed from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

let queryParamsFrozen = false;

// Just add query params here to have them automatically passed to topic list filters.
export const queryParams = {
  order: { replace: true, refreshModel: true },
  ascending: { replace: true, refreshModel: true, default: false },
  status: { replace: true, refreshModel: true },
  state: { replace: true, refreshModel: true },
  search: { replace: true, refreshModel: true },
  max_posts: { replace: true, refreshModel: true },
  min_posts: { replace: true, refreshModel: true },
  q: { replace: true, refreshModel: true },
  before: { replace: true, refreshModel: true },
  bumped_before: { replace: true, refreshModel: true },
  f: { replace: true, refreshModel: true },
  period: { replace: true, refreshModel: true },
  topic_ids: { replace: true, refreshModel: true },
  group_name: { replace: true, refreshModel: true },
  tags: { replace: true, refreshModel: true },
  match_all_tags: { replace: true, refreshModel: true },
  no_subcategories: { replace: true, refreshModel: true },
  no_tags: { replace: true, refreshModel: true },
  exclude_tag: { replace: true, refreshModel: true },
};

export function changeSort(sortBy) {
  let model = this.controllerFor("discovery.topics").model;

  if (sortBy === this.controller.order) {
    this.controller.toggleProperty("ascending");
    model.updateSortParams(sortBy, this.controller.ascending);
  } else {
    this.controller.setProperties({ order: sortBy, ascending: false });
    model.updateSortParams(sortBy, false);
  }
}

export function resetParams(skipParams = []) {
  Object.keys(queryParams).forEach((p) => {
    if (!skipParams.includes(p)) {
      this.controller.set(p, queryParams[p].default);
    }
  });
}

export const addDiscoveryQueryParam = function (p, opts) {
  if (queryParamsFrozen) {
    throw "DiscoverySortableController has already been initialized, new query parameters cannot be introduced";
  }
  queryParams[p] = opts;
};

export default class DiscoverySortableController extends Controller.extend(
  BulkTopicSelection
) {
  @tracked bulkSelectEnabled = false;

  queryParams = Object.keys(queryParams);

  constructor() {
    super(...arguments);
    this.queryParams.forEach((p) => {
      this[p] = queryParams[p].default;
    });
    queryParamsFrozen = true;
    this.resetSelected();
  }

  @discourseComputed("model.filter", "model.topics.length")
  showDismissRead(filter, topicsLength) {
    return (
      this._isFilterPage(this.model.get("filter"), "unread") && topicsLength > 0
    );
  }

  @discourseComputed("model.filter", "model.topics.length")
  showResetNew(filter, topicsLength) {
    return this._isFilterPage(filter, "new") && topicsLength > 0;
  }

  @action
  toggleBulkSelect() {
    this.bulkSelectEnabled = !this.bulkSelectEnabled;
  }
}
