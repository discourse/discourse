import AdminDashboard from 'admin/models/admin-dashboard';
import VersionCheck from 'admin/models/version-check';
import Report from 'admin/models/report';
import AdminUser from 'admin/models/admin-user';

export default Discourse.Route.extend({

  setupController: function(c) {
    this.fetchDashboardData(c);
  },

  fetchDashboardData: function(c) {
    if( !c.get('dashboardFetchedAt') || moment().subtract(30, 'minutes').toDate() > c.get('dashboardFetchedAt') ) {
      c.set('dashboardFetchedAt', new Date());
      var versionChecks = this.siteSettings.version_checks;
      AdminDashboard.find().then(function(d) {
        if (versionChecks) {
          c.set('versionCheck', VersionCheck.create(d.version_check));
        }

        ['global_reports', 'page_view_reports', 'private_message_reports', 'http_reports', 'user_reports', 'mobile_reports'].forEach(name => {
          c.set(name, d[name].map(r => Report.create(r)));
        });

        var topReferrers = d.top_referrers;
        if (topReferrers && topReferrers.data) {
          d.top_referrers.data = topReferrers.data.map(function (user) {
            return AdminUser.create(user);
          });
          c.set('top_referrers', topReferrers);
        }

        [ 'disk_space','admins', 'moderators', 'blocked', 'suspended',
          'top_traffic_sources', 'top_referred_topics', 'updated_at'].forEach(function(x) {
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

