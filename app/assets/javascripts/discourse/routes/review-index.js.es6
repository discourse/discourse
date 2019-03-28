export default Discourse.Route.extend({
  model(params) {
    // `0` is a valid query param
    if (params.min_score != null) {
      params.min_score = params.min_score.toString();
    }
    return this.store.findAll("reviewable", params);
  },

  setupController(controller, model) {
    let meta = model.resultSetMeta;
    controller.setProperties({
      reviewables: model,
      type: meta.type,
      filterType: meta.type,
      filterStatus: meta.status,
      filterTopic: meta.topic_id,
      filterCategoryId: meta.category_id,
      min_score: meta.min_score,
      filterScore: meta.min_score,
      reviewableTypes: meta.reviewable_types,
      filterUsername: meta.username
    });
  },

  actions: {
    refreshRoute() {
      this.refresh();
    }
  }
});
