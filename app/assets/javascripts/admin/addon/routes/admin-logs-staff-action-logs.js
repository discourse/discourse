import DiscourseRoute from "discourse/routes/discourse";
import EmberObject, { action } from "@ember/object";

export default class AdminLogsStaffActionLogsRoute extends DiscourseRoute {
  queryParams = {
    filters: { refreshModel: true },
  };

  beforeModel(transition) {
    const params = transition.to.queryParams;
    const controller = this.controllerFor("admin-logs-staff-action-logs");
    if (controller.filters === null || params.force_refresh) {
      controller.resetFilters();
    }
  }

  deserializeQueryParam(value, urlKey, defaultValueType) {
    if (urlKey === "filters") {
      return EmberObject.create(JSON.parse(decodeURIComponent(value)));
    }

    return super.deserializeQueryParam(value, urlKey, defaultValueType);
  }

  serializeQueryParam(value, urlKey, defaultValueType) {
    if (urlKey === "filters") {
      if (value && Object.keys(value).length > 0) {
        return JSON.stringify(value);
      } else {
        return null;
      }
    }

    return super.serializeQueryParam(value, urlKey, defaultValueType);
  }

  @action
  onFiltersChange(filters) {
    if (filters && Object.keys(filters) === 0) {
      this.transitionTo("adminLogs.staffActionLogs");
    } else {
      this.transitionTo("adminLogs.staffActionLogs", {
        queryParams: { filters },
      });
    }
  }
}
