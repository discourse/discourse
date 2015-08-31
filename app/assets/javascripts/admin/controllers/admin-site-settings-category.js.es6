export default Ember.Controller.extend({
  categoryNameKey: null,
  needs: ['adminSiteSettings'],

  filteredContent: function() {
    if (!this.get('categoryNameKey')) { return []; }

    const category = this.get('controllers.adminSiteSettings.content').findProperty('nameKey', this.get('categoryNameKey'));
    if (category) {
      return category.siteSettings;
    } else {
      return [];
    }
  }.property('controllers.adminSiteSettings.content', 'categoryNameKey')

});
