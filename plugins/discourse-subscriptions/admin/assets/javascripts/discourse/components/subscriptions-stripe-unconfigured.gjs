import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import { i18n } from "discourse-i18n";

const META_URL = "https://meta.discourse.org/t/discourse-subscriptions/140818/";

const SubscriptionsStripeUnconfigured = <template>
  <AdminConfigAreaEmptyList
    @emptyLabelTranslated={{i18n
      "discourse_subscriptions.admin.unconfigured"
      url=META_URL
    }}
    @ctaLabel="discourse_subscriptions.admin.configure_stripe"
    @ctaRoute="adminPlugins.show.settings"
    @ctaRouteModels="discourse-subscriptions"
    class="discourse-subscriptions-unconfigured"
  />
</template>;

export default SubscriptionsStripeUnconfigured;
