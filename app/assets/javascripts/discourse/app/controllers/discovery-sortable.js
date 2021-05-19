import Controller, { inject } from "@ember/controller";

// Just add query params here to have them automatically passed to topic list filters.
export const queryParams = {
  order: { replace: true, refreshModel: true },
  ascending: { replace: true, refreshModel: true, default: false },
  status: { replace: true, refreshModel: true },
  state: { replace: true, refreshModel: true },
  search: { replace: true, refreshModel: true },
  max_posts: { replace: true, refreshModel: true },
  q: { replace: true, refreshModel: true },
  tags: { replace: true },
  before: { replace: true, refreshModel: true },
  bumped_before: { replace: true, refreshModel: true },
  f: { replace: true, refreshModel: true },
};

// Basic controller options
const controllerOpts = {
  discoveryTopics: inject("discovery/topics"),
  queryParams: Object.keys(queryParams),
};

// Default to `null`
controllerOpts.queryParams.forEach((p) => {
  controllerOpts[p] = queryParams[p].default;
});

export function changeSort(sortBy) {
  let { controller } = this;
  let model = this.controllerFor("discovery.topics").model;
  if (sortBy === controller.order) {
    controller.toggleProperty("ascending");
    model.updateSortParams(sortBy, controller.ascending);
  } else {
    controller.setProperties({ order: sortBy, ascending: false });
    model.updateSortParams(sortBy, false);
  }
}

export function resetParams(skipParams = []) {
  let { controller } = this;
  controllerOpts.queryParams.forEach((p) => {
    if (!skipParams.includes(p)) {
      controller.set(p, queryParams[p].default);
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
