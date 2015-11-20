import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';
import StaffActionLog from 'admin/models/staff-action-log';

export default Ember.ArrayController.extend({
  loading: false,
  filters: null,

  filtersExists: Ember.computed.gt('filterCount', 0),

  actionFilter: function() {
    var name = this.get('filters.action_name');
    if (name) {
      return I18n.t("admin.logs.staff_actions.actions." + name);
    } else {
      return null;
    }
  }.property('filters.action_name'),

  showInstructions: Ember.computed.gt('model.length', 0),

  refresh: function() {
    var self = this;
    this.set('loading', true);

    var filters = this.get('filters'),
        params = {},
        count = 0;

    // Don't send null values
    Object.keys(filters).forEach(function(k) {
      var val = filters.get(k);
      if (val) {
        params[k] = val;
        count += 1;
      }
    });
    this.set('filterCount', count);

    StaffActionLog.findAll(params).then(function(result) {
      self.set('model', result);
    }).finally(function() {
      self.set('loading', false);
    });
  },

  resetFilters: function() {
    this.set('filters', Ember.Object.create());
    this.refresh();
  }.on('init'),

  _changeFilters: function(props) {
    this.get('filters').setProperties(props);
    this.refresh();
  },

  actions: {
    clearFilter: function(key) {
      var changed = {};

      // Special case, clear all action related stuff
      if (key === 'actionFilter') {
        changed.action_name = null;
        changed.action_id = null;
        changed.custom_type = null;
      } else {
        changed[key] = null;
      }
      this._changeFilters(changed);
    },

    clearAllFilters: function() {
      this.resetFilters();
    },

    filterByAction: function(logItem) {
      this._changeFilters({
        action_name: logItem.get('action_name'),
        action_id: logItem.get('action'),
        custom_type: logItem.get('custom_type')
      });
    },

    filterByStaffUser: function(acting_user) {
      this._changeFilters({ acting_user: acting_user.username });
    },

    filterByTargetUser: function(target_user) {
      this._changeFilters({ target_user: target_user.username });
    },

    filterBySubject: function(subject) {
      this._changeFilters({ subject: subject });
    },

    exportStaffActionLogs: function() {
      exportEntity('staff_action').then(outputExportResult);
    }
  }
});
