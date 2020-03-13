import Route from "@ember/routing/route";
export default Route.extend({
  model() {
    return this.store.findAll("plugin");
  },

  actions: {
    showSettings(plugin) {
      const controller = this.controllerFor("adminSiteSettings");
      this.transitionTo("adminSiteSettingsCategory", "plugins").then(() => {
        if (plugin) {
          const siteSettingFilter = plugin.get("enabled_setting_filter");
          const match = /^(.*)_enabled/.exec(plugin.get("enabled_setting"));
          const filter = siteSettingFilter || match[1];

          if (filter) {
            // filterContent() is normally on a debounce from typing.
            // Because we don't want the default of "All Results", we tell it
            // to skip the next debounce.
            controller.set("filter", filter);
            controller.set("_skipBounce", true);
            controller.filterContentNow("plugins");
          }
        }
      });
    }
  }
});
