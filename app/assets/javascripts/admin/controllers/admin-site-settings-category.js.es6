import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  categoryNameKey: null,
  adminSiteSettings: Ember.inject.controller(),

  @computed("adminSiteSettings.visibleSiteSettings", "categoryNameKey")
  category(categories, nameKey) {
    return (categories || []).findBy("nameKey", nameKey);
  },

  @computed("category")
  filteredContent(category) {
    return category ? category.siteSettings : [];
  }
});
