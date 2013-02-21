(function() {

  /**
    Handles the route that lists active users.

    @class AdminUsersListActiveRoute    
    @extends Discourse.Route
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminUsersListActiveRoute = Discourse.Route.extend({
    setupController: function() {
      return this.controllerFor('adminUsersList').show('active');
    }
  });

}).call(this);
