/**
  Handles the default admin route

  @class AdminDashboardRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminDashboardRoute = Discourse.Route.extend({
  setupController: function(c) {
    if( !c.get('versionCheckedAt') || Date.create('12 hours ago') > c.get('versionCheckedAt') ) {
      this.checkVersion(c);
    }
  },

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  checkVersion: function(c) {
    if( Discourse.SiteSettings.version_checks ) {
      Discourse.VersionCheck.find().then(function(vc) {
        c.set('versionCheck', vc);
        c.set('versionCheckedAt', new Date());
        c.set('loading', false);
      });
    }
  }
});

