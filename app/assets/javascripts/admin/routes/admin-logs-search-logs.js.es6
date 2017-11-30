import { ajax } from 'discourse/lib/ajax';

export default Discourse.Route.extend({
  renderTemplate() {
    this.render('admin/templates/logs/search-logs', {into: 'adminLogs'});
  },

  queryParams: {
    period: {
      refreshModel: true
    }
  },

  model(params) {
    this._params = params;
    return ajax('/admin/logs/search_logs.json', { data: { period: params.period } }).then(search_logs => {
      return search_logs.map(sl => Ember.Object.create(sl));
    });
  },

  setupController(controller, model) {
    const params = this._params;
    controller.setProperties({ model, period: params.period });
  }
});
