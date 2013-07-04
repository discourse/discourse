/**
  Handles routes related to users in the admin section.

  @class AdminUserRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminUserRoute = Discourse.Route.extend(Discourse.ModelReady, {

  serialize: function(params) {
    return { username: Em.get(params, 'username').toLowerCase() };
  },

  model: function(params) {
    return Discourse.AdminUser.find(Em.get(params, 'username').toLowerCase());
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    model.setOriginalTrustLevel();
  },

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  modelReady: function(controller, adminUser) {
    adminUser.loadDetails();
    controller.set('model', adminUser);
  }

});
