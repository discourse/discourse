/**
  This controller supports the default interface when you enter the admin section.

  @class AdminDashboardController
  @extends Ember.Controller
  @namespace Discourse
  @module Discourse  
**/
Discourse.AdminDashboardController = Ember.Controller.extend({
  loading: true,
  versionCheck: null,
  problemsCheckInterval: '1 minute ago',

  foundProblems: function() {
    return(Discourse.currentUser.admin && this.get('problems') && this.get('problems').length > 0);
  }.property('problems'),

  thereWereProblems: function() {
    if(!Discourse.currentUser.admin) { return false }
    if( this.get('foundProblems') ) {
      this.set('hadProblems', true);
      return true;
    } else {
      return this.get('hadProblems') || false;
    }
  }.property('foundProblems'),

  loadProblems: function() {
    this.set('loadingProblems', true);
    this.set('problemsFetchedAt', new Date());
    var c = this;
    Discourse.AdminDashboard.fetchProblems().then(function(d) {
      c.set('problems', d.problems);
      c.set('loadingProblems', false);
      if( d.problems && d.problems.length > 0 ) {
        c.problemsCheckInterval = '1 minute ago';
      } else {
        c.problemsCheckInterval = '10 minutes ago';
      }
    });
  },

  problemsTimestamp: function() {
    return this.get('problemsFetchedAt').long();
  }.property('problemsFetchedAt')
});
