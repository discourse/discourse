export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('groups.manage.title');
  },

  model() {
    return this.modelFor('group');
  },

  afterModel(group) {
    if (!this.currentUser || !this.currentUser.canManageGroup(group)) {
      this.transitionTo("group.members", group);
    }
  },

  setupController(controller, model) {
    this.controllerFor('group-manage').setProperties({ model });
    this.controllerFor("group").set("showing", 'manage');
  }
});
