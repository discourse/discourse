/**
  Handles the default admin route

  @class AdminDashboardRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminDashboardRoute = Discourse.Route.extend({

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
        c.set('top_referrers', d.top_referrers);
        c.set('top_traffic_sources', d.top_traffic_sources);
        c.set('top_referred_topics', d.top_referred_topics);
        c.set('loading', false);
      });
    } else if( !c.get('problemsFetchedAt') || Date.create(c.problemsCheckInterval, 'en') > c.get('problemsFetchedAt') ) {
      c.set('problemsFetchedAt', new Date());
      c.loadProblems();
    }
  },

  fetchGithubCommits: function(c) {
    if( !c.get('commitsCheckedAt') || Date.create('1 hour ago', 'en') > c.get('commitsCheckedAt') ) {
      c.set('commitsCheckedAt', new Date());
      c.set('githubCommits', Discourse.GithubCommit.findAll());
    }
  }
});

