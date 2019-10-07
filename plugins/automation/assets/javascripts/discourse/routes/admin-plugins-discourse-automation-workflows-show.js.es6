export default Discourse.Route.extend({
  controllerName: "workflows-show",

  model(params) {
    return this.store.find("workflow", params.id);
  },

  setupController(controller, model) {
    controller.setProperties({ formErrors: null, model });
  },

  renderTemplate() {
    this.render("workflows-show");
  },

  actions: {
    triggerRefresh() {
      this.refresh();
    }
  }
});
