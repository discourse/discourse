import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import StaffActionLog from "admin/models/staff-action-log";

export default Ember.Controller.extend({
  loading: false,
  filters: null,
  userHistoryActions: [],

  filtersExists: Ember.computed.gt("filterCount", 0),

  filterActionIdChanged: function() {
    const filterActionId = this.get("filterActionId");
    if (filterActionId) {
      this._changeFilters({
        action_name: this.get("userHistoryActions").findBy(
          "id",
          parseInt(filterActionId, 10)
        ).name_raw,
        action_id: filterActionId
      });
    }
  }.observes("filterActionId"),

  actionFilter: function() {
    var name = this.get("filters.action_name");
    if (name) {
      return I18n.t("admin.logs.staff_actions.actions." + name);
    } else {
      return null;
    }
  }.property("filters.action_name"),

  showInstructions: Ember.computed.gt("model.length", 0),

  _refresh() {
    this.set("loading", true);

    var filters = this.get("filters"),
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
    this.set("filterCount", count);

    StaffActionLog.findAll(params)
      .then(result => {
        this.set("model", result.staff_action_logs);
        if (this.get("userHistoryActions").length === 0) {
          let actionTypes = result.user_history_actions.map(pair => {
            return {
              id: pair.id,
              name: I18n.t("admin.logs.staff_actions.actions." + pair.name),
              name_raw: pair.name
            };
          });
          actionTypes = _.sortBy(actionTypes, row => row.name);
          this.set("userHistoryActions", actionTypes);
        }
      })
      .finally(() => {
        this.set("loading", false);
      });
  },

  scheduleRefresh() {
    Ember.run.scheduleOnce("afterRender", this, this._refresh);
  },

  resetFilters: function() {
    this.set("filters", Ember.Object.create());
    this.scheduleRefresh();
  }.on("init"),

  _changeFilters: function(props) {
    this.get("filters").setProperties(props);
    this.scheduleRefresh();
  },

  actions: {
    clearFilter: function(key) {
      var changed = {};

      // Special case, clear all action related stuff
      if (key === "actionFilter") {
        changed.action_name = null;
        changed.action_id = null;
        changed.custom_type = null;
        this.set("filterActionId", null);
      } else {
        changed[key] = null;
      }
      this._changeFilters(changed);
    },

    clearAllFilters() {
      this.set("filterActionId", null);
      this.resetFilters();
    },

    filterByAction: function(logItem) {
      this._changeFilters({
        action_name: logItem.get("action_name"),
        action_id: logItem.get("action"),
        custom_type: logItem.get("custom_type")
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
      exportEntity("staff_action").then(outputExportResult);
    }
  }
});
