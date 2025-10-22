import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminLogsStaffActionLogsRoute extends DiscourseRoute {
  @service router;

  queryParams = {
    filters: { refreshModel: true },
    startDate: { refreshModel: true },
    endDate: { refreshModel: true },
  };

  beforeModel(transition) {
    const params = transition.to.queryParams;
    const controller = this.controllerFor("admin-logs.staff-action-logs");
    if (controller.filters === null || params.force_refresh) {
      controller.resetFilters();
    }
  }

  deserializeQueryParam(value, urlKey, defaultValueType) {
    if (urlKey === "filters" && value) {
      return EmberObject.create(JSON.parse(decodeURIComponent(value)));
    }
    if (urlKey === "startDate" || urlKey === "endDate") {
      return value ? moment(value) : null;
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
    if (urlKey === "startDate" || urlKey === "endDate") {
      return value ? value.toISOString() : null;
    }

    return super.serializeQueryParam(value, urlKey, defaultValueType);
  }

  @action
  onFiltersChange(filters) {
    this.router.transitionTo("adminLogs.staffActionLogs", {
      queryParams: { filters },
    });
  }
}
