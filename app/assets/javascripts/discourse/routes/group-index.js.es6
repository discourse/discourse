export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.members');
  },

  model() {
    return this.modelFor("group");
  },

  setupController(controller, model) {
    this.controllerFor("group").set("showing", "members");
    controller.set("model", model);
    controller.refreshMembers();
  }
});
