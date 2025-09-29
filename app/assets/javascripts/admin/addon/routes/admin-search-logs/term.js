import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { translateResults } from "discourse/lib/search";
import { fillMissingDates } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminSearchLogsTermRoute extends DiscourseRoute {
  queryParams = {
    term: { refreshModel: true },
    period: { refreshModel: true },
    searchType: { refreshModel: true },
  };

  async model(params) {
    this._params = params;

    const json = await ajax(`/admin/logs/search_logs/term.json`, {
      data: {
        period: params.period,
        search_type: params.searchType,
        term: params.term,
      },
    });

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
      json.term.search_result = await translateResults(json.term.search_result);
    }

    const model = EmberObject.create({ type: "search_log_term" });
    model.setProperties(json.term);

    return model;
  }

  setupController(controller, model) {
    const params = this._params;
    controller.setProperties({
      model,
      term: params.term,
      period: params.period,
      searchType: params.searchType,
    });
  }
}
