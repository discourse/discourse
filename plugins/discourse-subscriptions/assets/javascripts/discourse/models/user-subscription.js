import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import Plan from "discourse/plugins/discourse-subscriptions/discourse/models/plan";

export default class UserSubscription extends EmberObject {
  static findAll() {
    return ajax("/s/user/subscriptions", { method: "get" }).then((result) =>
      result.map((subscription) => {
        subscription.plan = Plan.create(subscription.plan);
        return UserSubscription.create(subscription);
      })
    );
  }

  @computed("status")
  get canceled() {
    return this.status === "canceled";
  }

  @computed("current_period_end", "canceled_at")
  get endDate() {
    if (!this.canceled_at) {
      return moment.unix(this.current_period_end).format("LL");
    } else {
      return i18n("discourse_subscriptions.user.subscriptions.cancelled");
    }
  }

  @computed("discount")
  get discounted() {
    if (this.discount) {
      const amount_off = this.discount.coupon.amount_off;
      const percent_off = this.discount.coupon.percent_off;

      if (amount_off) {
        return `${parseFloat(amount_off * 0.01).toFixed(2)}`;
      } else if (percent_off) {
        return `${percent_off}%`;
      }
    } else {
      return i18n("no_value");
    }
  }

  destroy() {
    return ajax(`/s/user/subscriptions/${this.id}`, {
      method: "delete",
    }).then((result) => UserSubscription.create(result));
  }
}
