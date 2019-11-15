import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  queryParams: {
    start_date: { refreshModel: true },
    end_date: { refreshModel: true },
    filters: { refreshModel: true }
  },

  model(params) {
    params.customFilters = params.filters;
    delete params.filters;

    params.startDate =
      params.start_date ||
      moment
        .utc()
        .subtract(1, "day")
        .subtract(1, "month")
        .startOf("day")
        .format("YYYY-MM-DD");
    delete params.start_date;

    params.endDate =
      params.end_date ||
      moment
        .utc()
        .endOf("day")
        .format("YYYY-MM-DD");
    delete params.end_date;

    return params;
  },

  deserializeQueryParam(value, urlKey, defaultValueType) {
    if (urlKey === "filters") {
      return JSON.parse(decodeURIComponent(value));
    }

    return this._super(value, urlKey, defaultValueType);
  },

  serializeQueryParam(value, urlKey, defaultValueType) {
    if (urlKey === "filters") {
      if (value && Object.keys(value).length > 0) {
        return JSON.stringify(value);
      } else {
        return null;
      }
    }

    return this._super(value, urlKey, defaultValueType);
  },

  actions: {
    onParamsChange(params) {
      const queryParams = {
        type: params.type,
        start_date: params.startDate,
        filters: params.filters,
        end_date: params.endDate
      };

      this.transitionTo("adminReports.show", { queryParams });
    }
  }
});
