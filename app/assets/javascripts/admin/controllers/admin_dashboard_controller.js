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

  foundProblems: function() {
    return(this.get('problems') && this.get('problems').length > 0);
  }.property('problems')
});
