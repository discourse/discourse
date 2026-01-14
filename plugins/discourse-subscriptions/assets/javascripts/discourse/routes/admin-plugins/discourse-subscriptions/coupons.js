import { action } from "@ember/object";
import Route from "@ember/routing/route";
import AdminCoupon from "discourse/plugins/discourse-subscriptions/discourse/models/admin-coupon";

export default class AdminPluginsDiscourseSubscriptionsCouponsRoute extends Route {
  model() {
    return AdminCoupon.list();
  }

  @action
  reloadModel() {
    this.refresh();
  }
}
