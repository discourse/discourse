export default Discourse.Route.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model(params) {
    // If we refresh via `refreshModel` set the old model to loading
    const existing = this.modelFor('directory-show');
    if (existing) {
      existing.set('loading', true);
    }

    this._period = params.period;
    return this.store.find('directoryItem', {
      id: params.period,
      asc: params.asc,
      order: params.order
    });
  },

  setupController(controller, model) {
    controller.setProperties({ model, period: this._period });
  },

  actions: {
    changePeriod(period) {
      this.transitionTo('directory.show', period);
    }
  }
});
