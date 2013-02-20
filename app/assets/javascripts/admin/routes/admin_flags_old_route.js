(function() {

  Discourse.AdminFlagsOldRoute = Discourse.Route.extend({
    model: function() {
      return Discourse.FlaggedPost.findAll('old');
    },
    setupController: function(controller, model) {
      var c;
      c = this.controllerFor('adminFlags');
      c.set('content', model);
      return c.set('query', 'old');
    }
  });

}).call(this);
