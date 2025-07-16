import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "setup-subscriptions",
  initialize(container) {
    withPluginApi("0.8.11", (api) => {
      const siteSettings = container.lookup("service:site-settings");
      const isNavLinkEnabled =
        siteSettings.discourse_subscriptions_extra_nav_subscribe;
      const isPricingTableEnabled =
        siteSettings.discourse_subscriptions_pricing_table_enabled;
      const subscribeHref = isPricingTableEnabled ? "/s/subscriptions" : "/s";
      if (isNavLinkEnabled) {
        api.addNavigationBarItem({
          name: "subscribe",
          displayName: i18n("discourse_subscriptions.navigation.subscribe"),
          href: subscribeHref,
        });
      }

      const user = api.getCurrentUser();
      if (user) {
        api.addQuickAccessProfileItem({
          icon: "far-credit-card",
          href: `/u/${user.username}/billing/subscriptions`,
          content: "Billing",
        });
      }
    });
  },
};
