export default Ember.Route.extend({
  model() {
    return this.store.findAll('plugin');
  },

  actions: {
    showSettings() {
      this.transitionTo('adminSiteSettingsCategory', 'plugins');
    }
  }
});

