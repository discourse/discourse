import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class AdminReportsShowRoute extends DiscourseRoute {
  @service router;

  queryParams = {
    start_date: { refreshModel: true },
    end_date: { refreshModel: true },
    filters: { refreshModel: true },
    chart_grouping: { refreshModel: true },
    mode: { refreshModel: true },
  };

  model(params) {
    params.customFilters = params.filters;
    delete params.filters;

    params.startDate =
      params.start_date ||
      moment()
        .subtract(1, "day")
        .subtract(1, "month")
        .startOf("day")
        .format("YYYY-MM-DD");
    delete params.start_date;

    params.endDate =
      params.end_date || moment().endOf("day").format("YYYY-MM-DD");
    delete params.end_date;

    params.chartGrouping = params.chart_grouping || "daily";
    delete params.chart_grouping;

    return params;
  }

  deserializeQueryParam(value, urlKey, defaultValueType) {
    if (urlKey === "filters") {
      return JSON.parse(decodeURIComponent(value));
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
  onParamsChange(params) {
    const queryParams = {
      type: params.type,
      mode: params.mode,
      start_date: params.startDate
        ? params.startDate.toISOString(true).split("T")[0]
        : null,
      chart_grouping: params.chartGrouping,
      filters: params.filters,
      end_date: params.endDate
        ? params.endDate.toISOString(true).split("T")[0]
        : null,
    };

    this.router.transitionTo("adminReports.show", { queryParams });
  }
}
