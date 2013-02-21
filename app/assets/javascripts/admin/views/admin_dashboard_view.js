(function() {

  /**
    The default view in the admin section

    @class AdminDashboardView
    @extends Discourse.View
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminDashboardView = window.Discourse.View.extend({
    templateName: 'admin/templates/dashboard',

    updateIconClasses: function() {
      var classes;
      classes = "icon icon-warning-sign ";
      if (this.get('controller.versionCheck.critical_updates')) {
        classes += "critical-updates-available";
      } else {
        classes += "updates-available";
      }
      return classes;
    }.property('controller.versionCheck.critical_updates'),

    priorityClass: function() {
      if (this.get('controller.versionCheck.critical_updates')) {
        return 'version-check critical';
      }
      return 'version-check normal';
    }.property('controller.versionCheck.critical_updates')
  });

}).call(this);
