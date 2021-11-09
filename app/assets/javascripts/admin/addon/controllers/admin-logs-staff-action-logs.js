import Controller from "@ember/controller";
import EmberObject from "@ember/object";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import { scheduleOnce } from "@ember/runloop";

export default Controller.extend({
  queryParams: ["filters"],

  model: null,
  filters: null,
  userHistoryActions: null,

  @discourseComputed("filters.action_name")
  actionFilter(name) {
    return name ? I18n.t("admin.logs.staff_actions.actions." + name) : null;
  },

  @discourseComputed("filters")
  filtersExists(filters) {
    return filters && Object.keys(filters).length > 0;
  },

  _refresh() {
    this.store.findAll("staff-action-log", this.filters).then((result) => {
      this.set("model", result);

      if (!this.userHistoryActions) {
        this.set(
          "userHistoryActions",
          result.extras.user_history_actions
            .map((action) => ({
              id: action.id,
              action_id: action.action_id,
              name: I18n.t("admin.logs.staff_actions.actions." + action.id),
              name_raw: action.id,
            }))
            .sort((a, b) => a.name.localeCompare(b.name))
        );
      }
    });
  },

  scheduleRefresh() {
    scheduleOnce("afterRender", this, this._refresh);
  },

  resetFilters() {
    this.setProperties({
      model: EmberObject.create({ loadingMore: true }),
      filters: EmberObject.create(),
    });
    this.scheduleRefresh();
  },

  changeFilters(props) {
    this.set("model", EmberObject.create({ loadingMore: true }));

    if (!this.filters) {
      this.set("filters", EmberObject.create());
    }

    Object.keys(props).forEach((key) => {
      if (props[key] === undefined || props[key] === null) {
        this.filters.set(key, undefined);
        delete this.filters[key];
      } else {
        this.filters.set(key, props[key]);
      }
    });

    this.send("onFiltersChange", this.filters);
    this.scheduleRefresh();
  },

  actions: {
    filterActionIdChanged(filterActionId) {
      if (filterActionId) {
        this.changeFilters({
          action_name: filterActionId,
          action_id: this.userHistoryActions.findBy("id", filterActionId)
            .action_id,
        });
      }
    },

    clearFilter(key) {
      if (key === "actionFilter") {
        this.set("filterActionId", null);
        this.changeFilters({
          action_name: null,
          action_id: null,
          custom_type: null,
        });
      } else {
        this.changeFilters({ [key]: null });
      }
    },

    clearAllFilters() {
      this.set("filterActionId", null);
      this.resetFilters();
    },

    filterByAction(logItem) {
      this.changeFilters({
        action_name: logItem.get("action_name"),
        action_id: logItem.get("action"),
        custom_type: logItem.get("custom_type"),
      });
    },

    filterByStaffUser(acting_user) {
      this.changeFilters({ acting_user: acting_user.username });
    },

    filterByTargetUser(target_user) {
      this.changeFilters({ target_user: target_user.username });
    },

    filterBySubject(subject) {
      this.changeFilters({ subject });
    },

    exportStaffActionLogs() {
      exportEntity("staff_action").then(outputExportResult);
    },

    loadMore() {
      this.model.loadMore();
    },
  },
});
