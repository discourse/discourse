import { setting } from 'discourse/lib/computed';
import AdminDashboard from 'admin/models/admin-dashboard';
import VersionCheck from 'admin/models/version-check';
import Report from 'admin/models/report';
import AdminUser from 'admin/models/admin-user';
import computed from 'ember-addons/ember-computed-decorators';

const PROBLEMS_CHECK_MINUTES = 1;

const ATTRIBUTES = [ 'disk_space','admins', 'moderators', 'silenced', 'suspended', 'top_traffic_sources',
                     'top_referred_topics', 'updated_at'];

const REPORTS = [ 'global_reports', 'page_view_reports', 'private_message_reports', 'http_reports',
                  'user_reports', 'mobile_reports'];

// This controller supports the default interface when you enter the admin section.
export default Ember.Controller.extend({
  loading: null,
  versionCheck: null,
  dashboardFetchedAt: null,
  showVersionChecks: setting('version_checks'),

  @computed('problems.length')
  foundProblems(problemsLength) {
    return this.currentUser.get('admin') && (problemsLength || 0) > 0;
  },

  @computed('foundProblems')
  thereWereProblems(foundProblems) {
    if (!this.currentUser.get('admin')) { return false; }

    if (foundProblems) {
      this.set('hadProblems', true);
      return true;
    } else {
      return this.get('hadProblems') || false;
    }
  },

  fetchDashboard() {
    if (!this.get('dashboardFetchedAt') || moment().subtract(30, 'minutes').toDate() > this.get('dashboardFetchedAt')) {
      this.set('dashboardFetchedAt', new Date());
      this.set('loading', true);
      const versionChecks = this.siteSettings.version_checks;
      AdminDashboard.find().then(d => {
        if (versionChecks) {
          this.set('versionCheck', VersionCheck.create(d.version_check));
        }

        REPORTS.forEach(name => this.set(name, d[name].map(r => Report.create(r))));

        const topReferrers = d.top_referrers;
        if (topReferrers && topReferrers.data) {
          d.top_referrers.data = topReferrers.data.map(user => AdminUser.create(user));
          this.set('top_referrers', topReferrers);
        }

        ATTRIBUTES.forEach(a => this.set(a, d[a]));
        this.set('loading', false);
      });
    }

    if (!this.get('problemsFetchedAt') || moment().subtract(PROBLEMS_CHECK_MINUTES, 'minutes').toDate() > this.get('problemsFetchedAt')) {
      this.loadProblems();
    }
  },

  loadProblems() {
    this.set('loadingProblems', true);
    this.set('problemsFetchedAt', new Date());
    AdminDashboard.fetchProblems().then(d => {
      this.set('problems', d.problems);
    }).finally(() => {
      this.set('loadingProblems', false);
    });
  },

  @computed('problemsFetchedAt')
  problemsTimestamp(problemsFetchedAt) {
    return moment(problemsFetchedAt).format('LLL');
  },

  @computed('updated_at')
  updatedTimestamp(updatedAt) {
    return moment(updatedAt).format('LLL');
  },

  actions: {
    refreshProblems() {
      this.loadProblems();
    },
    showTrafficReport() {
      this.set("showTrafficReport", true);
    }
  }

});
