(function() {

  Discourse.AdminUsersListActiveRoute = Discourse.Route.extend({
    setupController: function(c) {
      return this.controllerFor('adminUsersList').show('active');
    }
  });

}).call(this);
