import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminSearchLogsIndexRoute extends DiscourseRoute {
  queryParams = {
    period: { refreshModel: true },
    searchType: { refreshModel: true },
  };

  async model(params) {
    this._params = params;
    const searchLogs = await ajax("/admin/logs/search_logs.json", {
      data: { period: params.period, search_type: params.searchType },
    });

    return searchLogs.map((log) => EmberObject.create(log));
  }

  setupController(controller, model) {
    const params = this._params;
    controller.setProperties({
      model,
      period: params.period,
      searchType: params.searchType,
    });
  }
}
