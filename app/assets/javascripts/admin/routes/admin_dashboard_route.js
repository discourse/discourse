(function() {

  /**
    Handles the default admin route

    @class AdminDashboardRoute    
    @extends Discourse.Route
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminDashboardRoute = Discourse.Route.extend({
    setupController: function(c) {
      if( Discourse.SiteSettings.version_checks ) {
        Discourse.VersionCheck.find().then(function(vc) {
          c.set('versionCheck', vc);
          c.set('loading', false);
        });
      }
    },

    renderTemplate: function() {
      this.render({into: 'admin/templates/admin'});
    }
  });

}).call(this);
