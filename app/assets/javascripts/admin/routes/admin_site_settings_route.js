/**
  Handles routes related to viewing and editing site settings.

  @class AdminSiteSettingsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteSettingsRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.SiteSetting.findAll();
  }
});
