import EmberObject, { computed } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";

export default class Plan extends EmberObject {
  @computed("unit_amount")
  get amountDollars() {
    return parseFloat(this.get("unit_amount") / 100).toFixed(2);
  }

  set amountDollars(value) {
    const decimal = parseFloat(value) * 100;
    this.set("unit_amount", decimal);
  }

  @discourseComputed("recurring.interval")
  billingInterval(interval) {
    return interval || "one-time";
  }

  @discourseComputed("amountDollars", "currency", "billingInterval")
  subscriptionRate(amountDollars, currency, interval) {
    return `${amountDollars} ${currency.toUpperCase()} / ${interval}`;
  }
}
