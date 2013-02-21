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

    upToDate: (function() {
      if (this.versionCheck) {
        return this.versionCheck.latest_version === this.versionCheck.installed_version;
      }
      return true;
    }).property('versionCheck'),

    updateIconClasses: (function() {
      var classes;
      classes = "icon icon-warning-sign ";
      if (this.get('versionCheck.critical_updates')) {
        classes += "critical-updates-available";
      } else {
        classes += "updates-available";
      }
      return classes;
    }).property('versionCheck'),

    priorityClass: (function() {
      if (this.get('versionCheck.critical_updates')) {
        return 'version-check critical';
      }
      return 'version-check normal';
    }).property('versionCheck')

  });

}).call(this);
