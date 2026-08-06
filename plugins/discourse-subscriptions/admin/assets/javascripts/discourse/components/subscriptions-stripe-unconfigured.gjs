import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import { i18n } from "discourse-i18n";

const SubscriptionsStripeUnconfigured = <template>
  <AdminConfigAreaEmptyList
    @emptyLabelTranslated={{i18n
      "discourse_subscriptions.admin.unconfigured"
      url="https://meta.discourse.org/t/-/140818/"
    }}
    @ctaLabel="discourse_subscriptions.admin.configure_stripe"
    @ctaRoute="adminPlugins.show.settings"
    @ctaRouteModels="discourse-subscriptions"
    class="discourse-subscriptions-unconfigured"
  />
</template>;

export default SubscriptionsStripeUnconfigured;
