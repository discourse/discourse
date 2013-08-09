/**
  This controller supports the interface for listing staff action logs in the admin section.

  @class AdminLogsStaffActionLogsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsStaffActionLogsController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.StaffActionLog.findAll().then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  },

  toggleFullDetails: function(target) {
    target.set('showFullDetails', !target.get('showFullDetails'));
  }
});
