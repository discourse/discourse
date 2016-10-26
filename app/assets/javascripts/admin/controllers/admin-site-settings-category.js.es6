export default Ember.Controller.extend({
  categoryNameKey: null,
  adminSiteSettings: Ember.inject.controller(),

  filteredContent: function() {
    if (!this.get('categoryNameKey')) { return []; }

    const category = (this.get('adminSiteSettings.model') || []).findBy('nameKey', this.get('categoryNameKey'));
    if (category) {
      return category.siteSettings;
    } else {
      return [];
    }
  }.property('adminSiteSettings.model', 'categoryNameKey')

});
