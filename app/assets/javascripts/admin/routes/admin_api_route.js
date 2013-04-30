/**
  Handles routes related to api

  @class AdminApiRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminApiRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  setupController: function(controller, model) {
    // in case you are wondering, model never gets called for link_to
    Discourse.AdminApi.find().then(function(result){
      controller.set('content', result);
    });
  }
});
