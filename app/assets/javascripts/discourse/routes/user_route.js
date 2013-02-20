(function() {

  window.Discourse.UserRoute = Discourse.Route.extend({
    model: function(params) {
      return Discourse.User.find(params.username);
    },
    serialize: function(params) {
      return {
        username: Em.get(params, 'username').toLowerCase()
      };
    }
  });

}).call(this);
