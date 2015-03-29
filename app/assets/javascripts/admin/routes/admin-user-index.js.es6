import showModal from 'discourse/lib/show-modal';

export default Discourse.Route.extend({
  model() {
    return this.modelFor('adminUser');
  },

  afterModel(model) {
    if (this.currentUser.get('admin')) {
      const self = this;
      return Discourse.Group.findAll().then(function(groups){
        self._availableGroups = groups.filterBy('automatic', false);
        return model;
      });
    }
  },

  setupController(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.get('primary_group_id'),
      availableGroups: this._availableGroups,
      model
    });
  },

  actions: {
    showSuspendModal(user) {
      showModal('modals/admin-suspend-user', user);
      this.controllerFor('modal').set('modalClass', 'suspend-user-modal');
    }
  }
});
