import { ajax } from "discourse/lib/ajax";
import { fillMissingDates } from "discourse/lib/utilities";
import { translateResults } from "discourse/lib/search";

export default Discourse.Route.extend({
  queryParams: {
    period: { refreshModel: true },
    searchType: { refreshModel: true }
  },

  model(params) {
    this._params = params;

    return ajax(`/admin/logs/search_logs/term/${params.term}.json`, {
      data: {
        period: params.period,
        search_type: params.searchType
      }
    }).then(json => {
      // Add zero values for missing dates
      if (json.term.data.length > 0) {
        const startDate =
          json.term.period === "all"
            ? moment(json.term.data[0].x).format("YYYY-MM-DD")
            : moment(json.term.start_date).format("YYYY-MM-DD");
        const endDate = moment(json.term.end_date).format("YYYY-MM-DD");
        json.term.data = fillMissingDates(json.term.data, startDate, endDate);
      }
      if (json.term.search_result) {
        json.term.search_result = translateResults(json.term.search_result);
      }

      const model = Ember.Object.create({ type: "search_log_term" });
      model.setProperties(json.term);
      return model;
    });
  },

  setupController(controller, model) {
    const params = this._params;
    controller.setProperties({
      model,
      term: params.term,
      period: params.period,
      searchType: params.searchType
    });
  }
});
