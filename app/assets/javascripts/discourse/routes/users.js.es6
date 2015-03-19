export default Discourse.Route.extend({
  queryParams: {
    period: { refreshModel: true },
    order: { refreshModel: true },
    asc: { refreshModel: true },
  },

  model(params) {
    // If we refresh via `refreshModel` set the old model to loading
    const existing = this.modelFor('users');
    if (existing) {
      existing.set('loading', true);
    }

    this._period = params.period;
    return this.store.find('directoryItem', params);
  },

  setupController(controller, model) {
    controller.setProperties({ model, period: this._period });
  }
});
