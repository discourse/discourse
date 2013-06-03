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
  }
});