import { ajax } from 'discourse/lib/ajax';

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
