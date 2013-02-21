(function() {

  /**
    Handles the route that lists new users.

    @class AdminUsersListNewRoute    
    @extends Discourse.Route
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminUsersListNewRoute = Discourse.Route.extend({
    setupController: function() {
      return this.controllerFor('adminUsersList').show('new');
    }  
  });

}).call(this);
