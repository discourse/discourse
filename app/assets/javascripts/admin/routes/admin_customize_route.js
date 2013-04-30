/**
  Handles routes related to customization

  @class AdminCustomizeRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminCustomizeRoute = Discourse.Route.extend({

  renderTemplate: function() {
    this.render({into: 'admin/templates/admin'});
  },

  setupController: function(controller, model) {
    // in case you are wondering, model never gets called for link_to
    controller.set('content',Discourse.SiteCustomization.findAll());
  }
});
