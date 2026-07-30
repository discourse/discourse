import Route from "@ember/routing/route";
import { service } from "@ember/service";

const PLUGIN_ID = "discourse-subscriptions";
const SHOW_ROUTE = "adminPlugins.show";

export default class StripeConfiguredRoute extends Route {
  @service router;
  @service siteSettings;

  beforeModel(transition) {
    if (this.siteSettings.discourse_subscriptions_public_key) {
      return;
    }

    if (this.#cameFromThisPlugin(transition.from)) {
      return;
    }

    this.router.replaceWith("adminPlugins.show.settings", PLUGIN_ID);
  }

  #cameFromThisPlugin(from) {
    let routeInfo = from;

    while (routeInfo) {
      if (routeInfo.name === SHOW_ROUTE) {
        return routeInfo.params?.plugin_id === PLUGIN_ID;
      }

      routeInfo = routeInfo.parent;
    }

    return false;
  }
}
