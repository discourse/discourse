import { withPluginApi } from "discourse/lib/plugin-api";
import SubscriptionsAdminPluginActions from "discourse/plugins/discourse-subscriptions/discourse/components/subscriptions-admin-plugin-actions";

const PLUGIN_ID = "discourse-subscriptions";

export default {
  name: "subscriptions-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "far-credit-card");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "discourse_subscriptions.admin.products.title",
          route: "adminPlugins.show.discourse-subscriptions-products",
        },
        {
          label: "discourse_subscriptions.admin.coupons.title",
          route: "adminPlugins.show.discourse-subscriptions-coupons",
        },
        {
          label: "discourse_subscriptions.admin.subscriptions.title",
          route: "adminPlugins.show.discourse-subscriptions-subscriptions",
        },
      ]);

      api.registerPluginHeaderActionComponent(
        PLUGIN_ID,
        SubscriptionsAdminPluginActions
      );
    });
  },
};
