import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { configNavForPlugin } from "discourse/lib/admin-plugin-config-nav";

export default class AdminPluginNavManager extends Service {
  @service currentUser;

  @tracked currentPlugin;

  // NOTE (martin) This is a temporary solution so we know whether to
  // show the expanded header / nav on the admin plugin list or not.
  // This will be removed when all plugins follow the new "show route" pattern.
  @tracked viewingPluginsList = false;

  get currentConfigNav() {
    const configNav = configNavForPlugin(this.currentPlugin.id);
    const settingsNav = {
      links: [
        {
          label: "admin.plugins.change_settings_short",
          route: "adminPlugins.show.settings",
        },
      ],
    };

    // Not all plugins have a more complex config UI and navigation,
    // in that case only the settings route will be available.
    if (!configNav) {
      return settingsNav;
    }

    // Automatically inject the settings link.
    if (
      !configNav.links.mapBy("route").includes("adminPlugins.show.settings")
    ) {
      configNav.links.unshift(settingsNav.links[0]);
    }
    return configNav;
  }

  get currentPluginDefaultRoute() {
    const currentConfigNavLinks = this.currentConfigNav.links;
    const linksExceptSettings = currentConfigNavLinks.reject(
      (link) => link.route === "adminPlugins.show.settings"
    );

    // Some plugins only have the Settings route, if so it's fine to use it as default.
    if (linksExceptSettings.length === 0) {
      return currentConfigNavLinks[0].route;
    }

    return linksExceptSettings[0].route;
  }
}
