/**
  Handles routes related to viewing and editing site settings within one category.

  @class AdminSiteSettingCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteSettingsCategoryRoute = Discourse.Route.extend({
  model: function(params) {
    this.controllerFor('adminSiteSettingsCategory').set('categoryNameKey', params.category_id);
    return this.modelFor('adminSiteSettings').find(function(category) {
      return category.nameKey === params.category_id;
    });
  }
});
