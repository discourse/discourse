import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class UserPayment extends EmberObject {
  static findAll() {
    return ajax("/s/user/payments", { method: "get" }).then((result) =>
      result.map((payment) => {
        return UserPayment.create(payment);
      })
    );
  }

  @computed("amount")
  get amountDollars() {
    return parseFloat(this.amount / 100).toFixed(2);
  }
}
