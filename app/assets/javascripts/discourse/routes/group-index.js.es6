export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.members.title');
  },

  model(params) {
    this._params = params;
    return this.modelFor("group");
  },

  setupController(controller, model) {
    this.controllerFor("group").set("showing", "members");

    controller.setProperties({
      model,
      filterInput: this._params.filter
    });

    controller.refreshMembers();
  }
});
