(function() {

  Discourse.AdminFlagsActiveRoute = Discourse.Route.extend({
    model: function() {
      return Discourse.FlaggedPost.findAll('active');
    },
    setupController: function(controller, model) {
      var c;
      c = this.controllerFor('adminFlags');
      c.set('content', model);
      return c.set('query', 'active');
    }
  });

}).call(this);
