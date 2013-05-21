/**
  Handles routes related to api

  @class AdminApiRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminApiRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.AdminApi.find();
  },

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  }

});
