import Route from "@ember/routing/route";
import { service } from "@ember/service";

const PLUGIN_ROUTE_PREFIX = "adminPlugins.show.";

// Without Stripe keys none of these pages have anything to show, so landing on
// the plugin goes straight to the settings tab. Clicking a tab is left alone —
// the page explains itself there, which a silent redirect cannot do.
export default class StripeConfiguredRoute extends Route {
  @service router;
  @service siteSettings;

  beforeModel(transition) {
    if (this.siteSettings.discourse_subscriptions_public_key) {
      return;
    }

    if (transition.from?.name?.startsWith(PLUGIN_ROUTE_PREFIX)) {
      return;
    }

    this.router.replaceWith(
      "adminPlugins.show.settings",
      "discourse-subscriptions"
    );
  }
}
