/**
  Handles routes related to users in the admin section.

  @class AdminUserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUserRoute = Discourse.Route.extend({

  serialize: function(params) {
    return { username: Em.get(params, 'username').toLowerCase() };
  },

  model: function(params) {
    return Discourse.AdminUser.find(Em.get(params, 'username').toLowerCase());
  },

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  afterModel: function(adminUser) {
    var controller = this.controllerFor('adminUser');

    adminUser.loadDetails().then(function () {
      adminUser.setOriginalTrustLevel();
      controller.set('model', adminUser);
      window.scrollTo(0, 0);
    });
  },

  actions: {
    showBanModal: function(user) {
      Discourse.Route.showModal(this, 'admin_ban_user', user);
      this.controllerFor('modal').set('modalClass', 'ban-user-modal');
    }
  }

});
