export default Discourse.Route.extend({
  titleToken() {
    return I18n.t("groups.index.title");
  },

  queryParams: {
    order: { refreshModel: true, replace: true },
    asc: { refreshModel: true, replace: true },
    filter: { refreshModel: true },
    type: { refreshModel: true, replace: true },
    username: { refreshModel: true }
  },

  refreshQueryWithoutTransition: true,

  model(params) {
    this._params = params;
    return this.store.findAll("group", params);
  },

  setupController(controller, model) {
    controller.setProperties({
      model,
      filterInput: this._params.filter
    });
  }
});
