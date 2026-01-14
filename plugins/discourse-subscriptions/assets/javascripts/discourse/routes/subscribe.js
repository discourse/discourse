import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class SubscribeRoute extends Route {
  @service router;
  @service siteSettings;

  beforeModel() {
    const pricingTableEnabled =
      this.siteSettings.discourse_subscriptions_pricing_table_enabled;

    if (pricingTableEnabled) {
      this.router.transitionTo("subscriptions");
    }
  }
}
