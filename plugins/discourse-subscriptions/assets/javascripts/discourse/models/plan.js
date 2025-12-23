import EmberObject, { computed } from "@ember/object";

export default class Plan extends EmberObject {
  @computed("unit_amount")
  get amountDollars() {
    return parseFloat(this.get("unit_amount") / 100).toFixed(2);
  }

  set amountDollars(value) {
    const decimal = parseFloat(value) * 100;
    this.set("unit_amount", decimal);
  }

  @computed("recurring.interval")
  get billingInterval() {
    return this.recurring?.interval || "one-time";
  }

  @computed("amountDollars", "currency", "billingInterval")
  get subscriptionRate() {
    return `${this.amountDollars} ${this.currency.toUpperCase()} / ${this.billingInterval}`;
  }
}
