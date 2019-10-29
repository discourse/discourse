import EmberObject from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import Controller from "@ember/controller";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  model: null,
  filters: null,
  filtersExists: Ember.computed.gt("filterCount", 0),
  userHistoryActions: null,

  @computed("filters.action_name")
  actionFilter(name) {
    return name ? I18n.t("admin.logs.staff_actions.actions." + name) : null;
  },

  @on("init")
  resetFilters() {
    this.setProperties({
      model: EmberObject.create({ loadingMore: true }),
      filters: EmberObject.create()
    });
    this.scheduleRefresh();
  },

  _changeFilters(props) {
    this.set("model", EmberObject.create({ loadingMore: true }));
    this.filters.setProperties(props);
    this.scheduleRefresh();
  },

  _refresh() {
    let filters = this.filters;
    let params = {};
    let count = 0;

    // Don't send null values
    Object.keys(filters).forEach(k => {
      let val = filters.get(k);
      if (val) {
        params[k] = val;
        count += 1;
      }
    });
    this.set("filterCount", count);

    this.store.findAll("staff-action-log", params).then(result => {
      this.set("model", result);

      if (!this.userHistoryActions) {
        this.set(
          "userHistoryActions",
          result.extras.user_history_actions
            .map(action => ({
              id: action.id,
              action_id: action.action_id,
              name: I18n.t("admin.logs.staff_actions.actions." + action.id),
              name_raw: action.id
            }))
            .sort((a, b) => a.name.localeCompare(b.name))
        );
      }
    });
  },

  scheduleRefresh() {
    scheduleOnce("afterRender", this, this._refresh);
  },

  actions: {
    filterActionIdChanged(filterActionId) {
      if (filterActionId) {
        this._changeFilters({
          action_name: filterActionId,
          action_id: this.userHistoryActions.findBy("id", filterActionId)
            .action_id
        });
      }
    },

    clearFilter(key) {
      let changed = {};

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

    filterByAction(logItem) {
      this._changeFilters({
        action_name: logItem.get("action_name"),
        action_id: logItem.get("action"),
        custom_type: logItem.get("custom_type")
      });
    },

    filterByStaffUser(acting_user) {
      this._changeFilters({ acting_user: acting_user.username });
    },

    filterByTargetUser(target_user) {
      this._changeFilters({ target_user: target_user.username });
    },

    filterBySubject(subject) {
      this._changeFilters({ subject: subject });
    },

    exportStaffActionLogs() {
      exportEntity("staff_action").then(outputExportResult);
    },

    loadMore() {
      this.model.loadMore();
    }
  }
});
