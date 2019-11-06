import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    return this.store.findAll("reviewable", params);
  },

  setupController(controller, model) {
    let meta = model.resultSetMeta;

    // "fast track" to update the current user's reviewable count before the message bus finds out.
    if (meta.reviewable_count !== undefined) {
      this.currentUser.set("reviewable_count", meta.reviewable_count);
    }

    controller.setProperties({
      reviewables: model,
      type: meta.type,
      filterType: meta.type,
      filterStatus: meta.status,
      filterTopic: meta.topic_id,
      filterCategoryId: meta.category_id,
      filterPriority: meta.priority,
      reviewableTypes: meta.reviewable_types,
      filterUsername: meta.username,
      filterSortOrder: meta.sort_order
    });
  },

  actions: {
    refreshRoute() {
      this.refresh();
    }
  }
});
