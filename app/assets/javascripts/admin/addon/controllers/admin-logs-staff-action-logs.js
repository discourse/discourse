import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import { scheduleOnce } from "@ember/runloop";
import showModal from "discourse/lib/show-modal";

export default class AdminLogsStaffActionLogsController extends Controller {
  queryParams = ["filters"];
  model = null;
  filters = null;
  userHistoryActions = null;

  @discourseComputed("filters.action_name")
  actionFilter(name) {
    return name ? I18n.t("admin.logs.staff_actions.actions." + name) : null;
  }

  @discourseComputed("filters")
  filtersExists(filters) {
    return filters && Object.keys(filters).length > 0;
  }

  _refresh() {
    this.store.findAll("staff-action-log", this.filters).then((result) => {
      this.set("model", result);

      if (!this.userHistoryActions) {
        this.set(
          "userHistoryActions",
          result.extras.user_history_actions
            .map((historyAction) => ({
              id: historyAction.id,
              action_id: historyAction.action_id,
              name: I18n.t(
                "admin.logs.staff_actions.actions." + historyAction.id
              ),
              name_raw: historyAction.id,
            }))
            .sort((a, b) => a.name.localeCompare(b.name))
        );
      }
    });
  }

  scheduleRefresh() {
    scheduleOnce("afterRender", this, this._refresh);
  }

  resetFilters() {
    this.setProperties({
      model: EmberObject.create({ loadingMore: true }),
      filters: EmberObject.create(),
    });
    this.scheduleRefresh();
  }

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
  }

  @action
  filterActionIdChanged(filterActionId) {
    if (filterActionId) {
      this.changeFilters({
        action_name: filterActionId,
        action_id: this.userHistoryActions.findBy("id", filterActionId)
          .action_id,
      });
    }
  }

  @action
  clearFilter(key, event) {
    event?.preventDefault();
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
  }

  @action
  clearAllFilters(event) {
    event?.preventDefault();
    this.set("filterActionId", null);
    this.resetFilters();
  }

  @action
  filterByAction(logItem, event) {
    event?.preventDefault();
    this.changeFilters({
      action_name: logItem.get("action_name"),
      action_id: logItem.get("action"),
      custom_type: logItem.get("custom_type"),
    });
  }

  @action
  filterByStaffUser(acting_user, event) {
    event?.preventDefault();
    this.changeFilters({ acting_user: acting_user.username });
  }

  @action
  filterByTargetUser(target_user, event) {
    event?.preventDefault();
    this.changeFilters({ target_user: target_user.username });
  }

  @action
  filterBySubject(subject, event) {
    event?.preventDefault();
    this.changeFilters({ subject });
  }

  @action
  exportStaffActionLogs() {
    exportEntity("staff_action").then(outputExportResult);
  }

  @action
  loadMore() {
    this.model.loadMore();
  }

  @action
  showDetailsModal(model, event) {
    event?.preventDefault();
    showModal("admin-staff-action-log-details", {
      model,
      admin: true,
      modalClass: "log-details-modal",
    });
  }

  @action
  showCustomDetailsModal(model, event) {
    event?.preventDefault();
    let modal = showModal("admin-theme-change", {
      model,
      admin: true,
      modalClass: "history-modal",
    });
    modal.loadDiff();
  }
}
