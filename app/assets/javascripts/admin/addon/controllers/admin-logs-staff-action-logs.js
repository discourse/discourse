import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import { i18n } from "discourse-i18n";
import AdminStaffActionLogComponent from "../components/modal/staff-action-log-change";
import StaffActionLogDetailsModal from "../components/modal/staff-action-log-details";

export default class AdminLogsStaffActionLogsController extends Controller {
  @service modal;
  @service store;

  queryParams = ["filters"];
  model = null;
  filters = null;
  userHistoryActions = null;

  @discourseComputed("filters.action_name")
  actionFilter(name) {
    return name ? i18n("admin.logs.staff_actions.actions." + name) : null;
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
              name: i18n(
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
    this.modal.show(StaffActionLogDetailsModal, {
      model: { staffActionLog: model },
    });
  }

  @action
  showCustomDetailsModal(model, event) {
    event?.preventDefault();
    this.modal.show(AdminStaffActionLogComponent, {
      model: { staffActionLog: model },
    });
  }
}
