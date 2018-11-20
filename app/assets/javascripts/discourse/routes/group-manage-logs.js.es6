export default Discourse.Route.extend({
  titleToken() {
    return I18n.t("groups.manage.logs.title");
  },

  model() {
    return this.modelFor("group").findLogs();
  },

  setupController(controller, model) {
    this.controllerFor("group-manage-logs").setProperties({ model });
  },

  actions: {
    willTransition() {
      this.controllerFor("group-manage-logs").reset();
    }
  }
});
