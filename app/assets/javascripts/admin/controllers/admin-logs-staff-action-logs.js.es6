import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import StaffActionLog from "admin/models/staff-action-log";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  loading: false,
  filters: null,
  userHistoryActions: [],
  model: null,
  nextPage: 0,
  lastPage: null,

  filtersExists: Ember.computed.gt("filterCount", 0),
  showTable: Ember.computed.gt("model.length", 0),

  @computed("filters.action_name")
  actionFilter(name) {
    return name ? I18n.t("admin.logs.staff_actions.actions." + name) : null;
  },

  @on("init")
  resetFilters() {
    this.setProperties({
      filters: Ember.Object.create(),
      model: [],
      nextPage: 0,
      lastPage: null
    });
    this.scheduleRefresh();
  },

  _changeFilters(props) {
    this.filters.setProperties(props);
    this.setProperties({
      model: [],
      nextPage: 0,
      lastPage: null
    });
    this.scheduleRefresh();
  },

  _refresh() {
    if (this.lastPage && this.nextPage >= this.lastPage) {
      return;
    }

    this.set("loading", true);

    const page = this.nextPage;
    let filters = this.filters;
    let params = { page };
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

    StaffActionLog.findAll(params)
      .then(result => {
        this.setProperties({
          model: this.model.concat(result.staff_action_logs),
          nextPage: page + 1
        });

        if (result.staff_action_logs.length === 0) {
          this.set("lastPage", page);
        }

        if (this.userHistoryActions.length === 0) {
          this.set(
            "userHistoryActions",
            result.user_history_actions
              .map(action => ({
                id: action.id,
                action_id: action.action_id,
                name: I18n.t("admin.logs.staff_actions.actions." + action.id),
                name_raw: action.id
              }))
              .sort((a, b) => (a.name > b.name ? 1 : -1))
          );
        }
      })
      .finally(() => this.set("loading", false));
  },

  scheduleRefresh() {
    Ember.run.scheduleOnce("afterRender", this, this._refresh);
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
      this._refresh();
    }
  }
});
