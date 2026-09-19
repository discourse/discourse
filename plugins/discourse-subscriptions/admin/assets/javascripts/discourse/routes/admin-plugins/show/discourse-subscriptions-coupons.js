import { action } from "@ember/object";
import StripeConfiguredRoute from "discourse/plugins/discourse-subscriptions/discourse/lib/stripe-configured-route";
import AdminCoupon from "discourse/plugins/discourse-subscriptions/discourse/models/admin-coupon";

export default class AdminPluginsDiscourseSubscriptionsCouponsRoute extends StripeConfiguredRoute {
  model() {
    return AdminCoupon.list();
  }

  @action
  reloadModel() {
    this.refresh();
  }
}
