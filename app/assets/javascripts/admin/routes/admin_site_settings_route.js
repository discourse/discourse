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
  },

  afterModel: function(siteSettings) {
    this.controllerFor('adminSiteSettings').set('allSiteSettings', siteSettings);
  }
});

/**
  Handles when you click the Site Settings tab in admin, but haven't
  chosen a category. It will redirect to the first category.
**/
Discourse.AdminSiteSettingsIndexRoute = Discourse.Route.extend({
  model: function() {
    this.replaceWith('adminSiteSettingsCategory', this.modelFor('adminSiteSettings')[0].nameKey);
  }
});
