/**
  The base admin route

  @class AdminRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('admin/templates/admin');
  }
});
