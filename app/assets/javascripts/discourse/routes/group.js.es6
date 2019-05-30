export default Discourse.Route.extend({
  titleToken() {
    return [this.modelFor("group").name];
  },

  model(params) {
    return this.store.find("group", params.name);
  },

  serialize(model) {
    return { name: model.name.toLowerCase() };
  },

  setupController(controller, model) {
    controller.setProperties({ model });
  }
});
