/**
  Handles the default admin route

  @class AdminDashboardRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/

export default Discourse.Route.extend({

  setupController: function(c) {
    this.fetchDashboardData(c);
  },

  fetchDashboardData: function(c) {
    if( !c.get('dashboardFetchedAt') || moment().subtract(30, 'minutes').toDate() > c.get('dashboardFetchedAt') ) {
      c.set('dashboardFetchedAt', new Date());
      Discourse.AdminDashboard.find().then(function(d) {
        if( Discourse.SiteSettings.version_checks ){
          c.set('versionCheck', Discourse.VersionCheck.create(d.version_check));
        }
        _.each(d.reports,function(report){
          c.set(report.type, Discourse.Report.create(report));
        });

        var topReferrers = d.top_referrers;
        if (topReferrers && topReferrers.data) {
          d.top_referrers.data = topReferrers.data.map(function (user) {
            return Discourse.AdminUser.create(user);
          });
          c.set('top_referrers', topReferrers);
        }

        ['admins', 'moderators', 'blocked', 'suspended', 'top_traffic_sources', 'top_referred_topics', 'updated_at'].forEach(function(x) {
          c.set(x, d[x]);
        });

        c.set('loading', false);
      });
    }

    if( !c.get('problemsFetchedAt') || moment().subtract(c.problemsCheckMinutes, 'minutes').toDate() > c.get('problemsFetchedAt') ) {
      c.set('problemsFetchedAt', new Date());
      c.loadProblems();
    }
  }
});

