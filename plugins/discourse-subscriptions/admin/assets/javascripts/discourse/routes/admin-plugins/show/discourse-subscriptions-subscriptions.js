import StripeConfiguredRoute from "discourse/plugins/discourse-subscriptions/discourse/lib/stripe-configured-route";
import AdminSubscription from "discourse/plugins/discourse-subscriptions/discourse/models/admin-subscription";

export default class AdminPluginsDiscourseSubscriptionsSubscriptionsRoute extends StripeConfiguredRoute {
  model() {
    return AdminSubscription.find();
  }
}
