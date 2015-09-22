export default Ember.Route.extend({
  model() {
    return this.store.findAll('plugin');
  },

  actions: {
    showSettings(plugin) {
      const controller = this.controllerFor('adminSiteSettings');
      this.transitionTo('adminSiteSettingsCategory', 'plugins').then(() => {
        if (plugin) {
          const match = /^(.*)_enabled/.exec(plugin.get('enabled_setting'));
          if (match[1]) {
            // filterContent() is normally on a debounce from typing.
            // Because we don't want the default of "All Results", we tell it
            // to skip the next debounce.
            controller.set('filter', match[1]);
            controller.set('_skipBounce', true);
            controller.filterContentNow('plugins');
          }
        }
      });
    }
  }
});

