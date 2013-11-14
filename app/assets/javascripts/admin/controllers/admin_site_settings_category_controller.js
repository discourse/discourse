Discourse.AdminSiteSettingsCategoryController = Ember.ObjectController.extend({
  categoryNameKey: null,
  needs: ['adminSiteSettings'],

  filteredContent: function() {
    if (!this.get('categoryNameKey')) { return Em.A(); }

    var category = this.get('controllers.adminSiteSettings.content').find(function(siteSettingCategory) {
      return siteSettingCategory.nameKey === this.get('categoryNameKey');
    }, this);

    if (category) {
      return category.siteSettings;
    } else {
      return Em.A();
    }
  }.property('controllers.adminSiteSettings.content', 'categoryNameKey')

});
