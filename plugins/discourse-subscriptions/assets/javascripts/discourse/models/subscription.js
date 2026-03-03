import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class Subscription extends EmberObject {
  static show(id) {
    return ajax(`/s/${id}`, { method: "get" });
  }

  @computed("status")
  get canceled() {
    return this.status === "canceled";
  }

  save() {
    const data = {
      source: this.source,
      plan: this.plan,
      promo: this.promo,
      cardholder_name: this.cardholderName,
      cardholder_address: this.cardholderAddress,
    };

    return ajax("/s/create", { method: "post", data });
  }
}
