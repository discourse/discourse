/**
  Handles routes related to viewing and editing site settings within one category.

  @class AdminSiteSettingCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteSettingsCategoryRoute = Discourse.Route.extend({
  model: function(params) {
    var category = this.modelFor('adminSiteSettings').find(function(siteSettingCategory) {
      return siteSettingCategory.nameKey === params.category_id;
    });
    if (category) {
      return category.siteSettings;
    }
  }
});
