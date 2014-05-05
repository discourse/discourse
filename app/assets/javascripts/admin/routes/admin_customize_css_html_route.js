/**
  Handles routes related to css/html customization

  @class AdminCustomizeCssHtmlRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminCustomizeCssHtmlRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.SiteCustomization.findAll();
  }

});
