(function() {

  Discourse.AdminUserRoute = Discourse.Route.extend({
    model: function(params) {
      return Discourse.AdminUser.find(params.username);
    }
  });

}).call(this);
