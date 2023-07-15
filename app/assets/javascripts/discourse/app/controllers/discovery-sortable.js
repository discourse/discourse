import Controller, { inject as controller } from "@ember/controller";

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

// Basic controller options
const controllerOpts = {
  // discoveryTopics: controller("discovery/topics"),
  queryParams: Object.keys(queryParams),
};

// Default to `undefined`
controllerOpts.queryParams.forEach((p) => {
  controllerOpts[p] = queryParams[p].default;
});

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
  controllerOpts.queryParams.forEach((p) => {
    if (!skipParams.includes(p)) {
      this.controller.set(p, queryParams[p].default);
    }
  });
}

const SortableController = Controller.extend(controllerOpts);

export const addDiscoveryQueryParam = function (p, opts) {
  queryParams[p] = opts;
  const cOpts = {};
  cOpts[p] = null;
  cOpts["queryParams"] = Object.keys(queryParams);
  SortableController.reopen(cOpts);
};

export default SortableController;
