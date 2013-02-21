(function() {

  /**
    This controller supports the default interface when you enter the admin section.

    @class AdminDashboardController
    @extends Ember.Controller
    @namespace Discourse
    @module Discourse
  **/
  window.Discourse.AdminDashboardController = Ember.Controller.extend({
    loading: true,
    versionCheck: null,

    upToDate: function() {
      if (this.get('versionCheck')) {
        return this.get('versionCheck.latest_version') === this.get('versionCheck.installed_version');
      }
      return true;
    }.property('versionCheck'),

    updateIconClasses: function() {
      var classes;
      classes = "icon icon-warning-sign ";
      if (this.get('versionCheck.critical_updates')) {
        classes += "critical-updates-available";
      } else {
        classes += "updates-available";
      }
      return classes;
    }.property('versionCheck.critical_updates'),

    priorityClass: function() {
      if (this.get('versionCheck.critical_updates')) {
        return 'version-check critical';
      }
    }.property('versionCheck.critical_updates'),

    gitLink: function() {
      return "https://github.com/discourse/discourse/tree/" + this.get('versionCheck.installed_sha');
    }.property('versionCheck.installed_sha'),

    shortSha: function() {
      return this.get('versionCheck.installed_sha').substr(0,10);
    }.property('versionCheck.installed_sha')
  });

}).call(this);
