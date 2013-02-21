(function() {

  /**
    Handles the route that lists pending users.

    @class AdminUsersListNewRoute    
    @extends Discourse.Route
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminUsersListPendingRoute = Discourse.Route.extend({
    setupController: function() {
      return this.controllerFor('adminUsersList').show('pending');
    }   
  });

}).call(this);
