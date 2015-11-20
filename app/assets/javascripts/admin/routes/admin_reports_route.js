/**
  Handles routes for admin reports

  @class AdminReportsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminReportsRoute = Discourse.Route.extend({
  model: function(params) {
    return Discourse.Report.find(params.type);
  },

  setupController: function(controller, model) {
    controller.setProperties({
      model: model,
      categoryId: 'all',
      startDate: moment(model.get('start_date')).format('YYYY-MM-DD'),
      endDate: moment(model.get('end_date')).format('YYYY-MM-DD')
    });
  }
});
