/**
  Handles routes related to users in the admin section.

  @class AdminUserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
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
    var controller = this.controllerFor('adminUser');

    return adminUser.loadDetails().then(function () {
      adminUser.setOriginalTrustLevel();
      controller.set('model', adminUser);
    });
  },

  setupController: function(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.get('primary_group_id'),
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

Discourse.AdminUserIndexRoute = Discourse.Route.extend({
  setupController: function(c) {
    c.set('model', this.controllerFor('adminUser').get('model'));
  }
});
