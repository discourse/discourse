export default Ember.Route.extend({
  titleToken() {
    return I18n.t('groups.edit.title');
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
    this.controllerFor('group-edit').setProperties({ model });
    this.controllerFor("group").set("showing", 'edit');
    model.findMembers();
  }
});
