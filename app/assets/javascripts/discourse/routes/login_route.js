Discourse.LoginRoute = Discourse.Route.extend({
  beforeModel: function() {
    if (!Discourse.SiteSetting.login_required) {
      this.transitionTo('discovery.latest').then(function(e) {
        Ember.run.next(function() {
          e.send('showLogin');
        });
      });
    }
  }
});
