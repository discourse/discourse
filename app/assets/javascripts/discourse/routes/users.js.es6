export default Discourse.Route.extend({
  queryParams: {
    period: { refreshModel: true },
    order: { refreshModel: true },
    asc: { refreshModel: true }
  },

  refreshModel(params) {
    const controller = this.controllerFor('users');
    controller.set('model.loading', true);

    this.model(params).then(model => this.setupController(controller, model));
  },

  model(params) {
    // If we refresh via `refreshModel` set the old model to loading
    this._period = params.period;
    return this.store.find('directoryItem', params);
  },

  setupController(controller, model) {
    controller.setProperties({ model, period: this._period });
  }
});
