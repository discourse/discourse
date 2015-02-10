export default Ember.Route.extend({
  model() {
    return Discourse.ajax("/admin/plugins.json").then(res => res.plugins);
  },

  actions: {
    showSettings() {
      this.transitionTo('adminSiteSettingsCategory', 'plugins');
    }
  }
});

