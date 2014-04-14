Discourse.SignupRoute = Discourse.Route.extend({
  beforeModel: function() {
    this.transitionTo('discovery.latest').then(function(e) {
      Ember.run.next(function() {
        e.send('showCreateAccount');
      });
    });
  }
});
