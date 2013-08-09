/**
  This controller supports the interface for listing staff action logs in the admin section.

  @class AdminLogsStaffActionLogsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsStaffActionLogsController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  filters: {},

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.URL.set('queryParams', this.get('filters')); // TODO: doesn't work
    Discourse.StaffActionLog.findAll(this.get('filters')).then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  }.observes('filters.action_name', 'filters.staff_user', 'filters.target_user'),

  toggleFullDetails: function(target) {
    target.set('showFullDetails', !target.get('showFullDetails'));
  },

  filtersExists: function() {
    return (_.size(this.get('filters')) > 0);
  }.property('filters.action_name', 'filters.staff_user', 'filters.target_user'),

  clearFilter: function(key) {
    delete this.get('filters')[key];
    this.notifyPropertyChange('filters');
  },

  clearAllFilters: function() {
    this.set('filters', {});
  },

  filterByAction: function(action) {
    this.set('filters.action_name', action);
  },

  actionFilter: function() {
    if (this.get('filters.action_name')) {
      return I18n.t("admin.logs.staff_actions.actions." + this.get('filters.action_name'));
    } else {
      return null;
    }
  }.property('filters.action_name'),

  filterByStaffUser: function(staff_user) {
    this.set('filters.staff_user', staff_user.username);
  },

  filterByTargetUser: function(target_user) {
    this.set('filters.target_user', target_user.username);
  }
});
