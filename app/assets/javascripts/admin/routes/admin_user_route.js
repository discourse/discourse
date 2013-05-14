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

  renderTemplate: function() {
    this.render('admin/templates/user', {into: 'admin/templates/admin'});
  },

  setupController: function(controller, model) {
    Discourse.AdminUser.find(Em.get(model, 'username').toLowerCase()).then(function (u) {
      controller.set('content', u);
    });
  }

});
