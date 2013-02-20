(function() {

  Discourse.AdminDashboardRoute = Discourse.Route.extend({
    setupController: function(c) {
      return Discourse.VersionCheck.find().then(function(vc) {
        c.set('versionCheck', vc);
        return c.set('loading', false);
      });
    }
  });

}).call(this);
