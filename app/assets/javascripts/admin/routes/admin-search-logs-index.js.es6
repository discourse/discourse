import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  queryParams: {
    period: { refreshModel: true },
    searchType: { refreshModel: true }
  },

  model(params) {
    this._params = params;
    return ajax("/admin/logs/search_logs.json", {
      data: { period: params.period, search_type: params.searchType }
    }).then(search_logs => {
      return search_logs.map(sl => Ember.Object.create(sl));
    });
  },

  setupController(controller, model) {
    const params = this._params;
    controller.setProperties({
      model,
      period: params.period,
      searchType: params.searchType
    });
  }
});
