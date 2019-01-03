export default Discourse.Route.extend({
  model(params) {
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
      filterScore: meta.min_score
    });
  },

  actions: {
    refreshRoute() {
      this.refresh();
    }
  }
});
