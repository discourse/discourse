/**
  This controller supports the interface for listing staff action logs in the admin section.

  @class AdminLogsStaffActionLogsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsStaffActionLogsController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  filters: null,

  show: function(filters) {
    var self = this;
    this.set('loading', true);
    Discourse.StaffActionLog.findAll(this.get('filters')).then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  },

  toggleFullDetails: function(target) {
    target.set('showFullDetails', !target.get('showFullDetails'));
  },

  clearFiltersClass: function() {
    if (this.get('filters') === null) {
      return 'invisible';
    } else {
      return '';
    }
  }.property('filters'),

  clearFilters: function() {
    this.set('filters', null);
    this.show();
  },

  filterByAction: function(action) {
    this.set('filters', {action_name: action});
    this.show();
  }
});
