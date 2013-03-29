/**
  Handles the default admin route

  @class AdminDashboardRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminDashboardRoute = Discourse.Route.extend({

  problemsCheckInterval: '1 minute ago',

  setupController: function(c) {
    this.fetchDashboardData(c);
    this.fetchGithubCommits(c);
  },

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  fetchDashboardData: function(c) {
    if( !c.get('dashboardFetchedAt') || Date.create('1 hour ago', 'en') > c.get('dashboardFetchedAt') ) {
      c.set('dashboardFetchedAt', new Date());
      c.set('problemsFetchedAt', new Date());
      Discourse.AdminDashboard.find().then(function(d) {
        if( Discourse.SiteSettings.version_checks ){
          c.set('versionCheck', Discourse.VersionCheck.create(d.version_check));
        }
        d.reports.each(function(report){
          c.set(report.type, Discourse.Report.create(report));
        });
        c.set('admins', d.admins);
        c.set('moderators', d.moderators);
        c.set('problems', d.problems);
        c.set('loading', false);
      });
    } else if( !c.get('problemsFetchedAt') || Date.create(this.problemsCheckInterval, 'en') > c.get('problemsFetchedAt') ) {
      c.set('problemsFetchedAt', new Date());
      var _this = this;
      Discourse.AdminDashboard.fetchProblems().then(function(d) {
        c.set('problems', d.problems);
        c.set('loading', false);
        if( d.problems && d.problems.length > 0 ) {
          _this.problemsCheckInterval = '1 minute ago';
        } else {
          _this.problemsCheckInterval = '10 minutes ago';
        }
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

