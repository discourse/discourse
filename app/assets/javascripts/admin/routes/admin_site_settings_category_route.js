/**
  Handles routes related to viewing and editing site settings within one category.

  @class AdminSiteSettingCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteSettingsCategoryRoute = Discourse.Route.extend({
  model: function(params) {
    // The model depends on user input, so let the controller do the work:
    this.controllerFor('adminSiteSettingsCategory').set('categoryNameKey', params.category_id);
    return Em.Object.create({
      nameKey: params.category_id,
      name: I18n.t('admin.site_settings.categories.' + params.category_id),
      siteSettings: this.controllerFor('adminSiteSettingsCategory').get('filteredContent')
    });
  }
});
