Discourse.AdminUserRoute = Discourse.Route.extend({
  serialize: function(model) {
    return { username: model.get('username').toLowerCase() };
  },

  model: function(params) {
    return Discourse.AdminUser.find(Em.get(params, 'username').toLowerCase());
  },

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  afterModel: function(adminUser) {
    return adminUser.loadDetails().then(function () {
      adminUser.setOriginalTrustLevel();
      return adminUser;
    });
  }
});

Discourse.AdminUserIndexRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('adminUser');
  },

  afterModel: function(model) {
    if(Discourse.User.currentProp('admin')) {
      var self = this;
      return Discourse.Group.findAll().then(function(groups){
        self._availableGroups = groups.filterBy('automatic', false);
        return model;
      });
    }
  },

  setupController: function(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.get('primary_group_id'),
      availableGroups: this._availableGroups,
      model: model
    });
  },

  actions: {
    showSuspendModal: function(user) {
      Discourse.Route.showModal(this, 'admin_suspend_user', user);
      this.controllerFor('modal').set('modalClass', 'suspend-user-modal');
    }
  }
});
