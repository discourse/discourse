/**
  Handles routes related to customization

  @class AdminCustomizeIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminCustomizeIndexRoute = Discourse.Route.extend({
  redirect: function() {
    this.transitionTo('adminCustomize.colors');
  }
});
