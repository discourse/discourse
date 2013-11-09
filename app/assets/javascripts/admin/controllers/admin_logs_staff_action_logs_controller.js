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
  }.observes('filters.action_name', 'filters.acting_user', 'filters.target_user', 'filters.subject'),

  filtersExists: function() {
    return (_.size(this.get('filters')) > 0);
  }.property('filters.action_name', 'filters.acting_user', 'filters.target_user', 'filters.subject'),

  actionFilter: function() {
    if (this.get('filters.action_name')) {
      return I18n.t("admin.logs.staff_actions.actions." + this.get('filters.action_name'));
    } else {
      return null;
    }
  }.property('filters.action_name'),

  showInstructions: function() {
    return this.get('model.length') > 0;
  }.property('loading', 'model.length'),

  actions: {
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

    filterByStaffUser: function(acting_user) {
      this.set('filters.acting_user', acting_user.username);
    },

    filterByTargetUser: function(target_user) {
      this.set('filters.target_user', target_user.username);
    },

    filterBySubject: function(subject) {
      this.set('filters.subject', subject);
    }
  }
});
