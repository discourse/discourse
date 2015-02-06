export default Ember.Route.extend({
  model() {
    return Discourse.ajax("/admin/plugins.json");
  },

  actions: {
    showSettings() {
      this.transitionTo('adminSiteSettingsCategory', 'plugins');
    }
  }
});

