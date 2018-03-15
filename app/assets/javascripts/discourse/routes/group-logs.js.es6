export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.logs.title');
  },

  model() {
    return this.modelFor('group').findLogs();
  },

  setupController(controller, model) {
    this.controllerFor('group-logs').setProperties({ model });
    this.controllerFor("group").set("showing", 'logs');
  },

  actions: {
    willTransition() {
      this.controllerFor('group-logs').reset();
    }
  }
});
