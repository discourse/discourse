(function() {

  /**
    Handles the route that deals with listing users

    @class AdminUsersListRoute    
    @extends Discourse.Route
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminUsersListRoute = Discourse.Route.extend({
    renderTemplate: function() {
      this.render('admin/templates/users_list', {into: 'admin/templates/admin'});
    }    
  });

}).call(this);
