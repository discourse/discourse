/**
  Handles the default admin route

  @class AdminDashboardRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminDashboardRoute = Discourse.Route.extend({
  setupController: function(c) {
    this.checkVersion(c);
    this.fetchReports(c);
    this.fetchGithubCommits(c);
  },

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  checkVersion: function(c) {
    if( Discourse.SiteSettings.version_checks && (!c.get('versionCheckedAt') || Date.create('12 hours ago', 'en') > c.get('versionCheckedAt')) ) {
      c.set('versionCheckedAt', new Date());
      Discourse.VersionCheck.find().then(function(vc) {
        c.set('versionCheck', vc);
        c.set('loading', false);
      });
    }
  },

  fetchReports: function(c) {
    if( !c.get('reportsCheckedAt') || Date.create('1 hour ago', 'en') > c.get('reportsCheckedAt') ) {
      // TODO: use one request to get all reports, or maybe one request for all dashboard data including version check.
      c.set('reportsCheckedAt', new Date());
      ['visits', 'signups', 'topics', 'posts', 'total_users', 'flags'].each(function(reportType){
        c.set(reportType,  Discourse.Report.find(reportType));
      });
    }
  },

  fetchGithubCommits: function(c) {
    if( !c.get('commitsCheckedAt') || Date.create('1 hour ago', 'en') > c.get('commitsCheckedAt') ) {
      c.set('commitsCheckedAt', new Date());
      c.set('githubCommits', Discourse.GithubCommit.findAll());
    }
  }
});

