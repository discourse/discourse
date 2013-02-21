(function() {

  Discourse.AdminDashboardRoute = Discourse.Route.extend({
    setupController: function(c) {
      if( Discourse.SiteSettings.version_checks ) {
        return Discourse.VersionCheck.find().then(function(vc) {
          c.set('versionCheck', vc);
          return c.set('loading', false);
        });
      }
    }
  });

}).call(this);
