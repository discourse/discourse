/**
  Handles routes for admin reports

  @class AdminReportsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
export default Discourse.Route.extend({
  queryParams: { mode: {}, "start_date": {}, "end_date": {}, "category_id": {}, "group_id": {} },

  model: function(params) {
    const Report = require('admin/models/report').default;
    return Report.find(params.type, params['start_date'], params['end_date'], params['category_id'], params['group_id']);
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      categoryId: (model.get('category_id') || 'all'),
      groupId: model.get('group_id'),
      startDate: moment(model.get('start_date')).format('YYYY-MM-DD'),
      endDate: moment(model.get('end_date')).format('YYYY-MM-DD')
    });
  }
});
