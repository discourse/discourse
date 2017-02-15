export default Ember.Route.extend({
  titleToken() {
    return I18n.t('groups.edit.title');
  },

  model() {
    return this.modelFor('group');
  },

  setupController(controller, model) {
    this.controllerFor('group-edit').setProperties({ model });
    this.controllerFor("group").set("showing", 'edit');
    model.findMembers();
  }
});
