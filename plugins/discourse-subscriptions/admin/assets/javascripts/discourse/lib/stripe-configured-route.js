import Route from "@ember/routing/route";
import { service } from "@ember/service";

const PLUGIN_ID = "discourse-subscriptions";
const SHOW_ROUTE = "adminPlugins.show";

export default class StripeConfiguredRoute extends Route {
  @service router;
  @service site;

  beforeModel(transition) {
    if (this.site.discourse_subscriptions_stripe_configured) {
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
