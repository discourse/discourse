import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";

export default class UserPayment extends EmberObject {
  static findAll() {
    return ajax("/s/user/payments", { method: "get" }).then((result) =>
      result.map((payment) => {
        return UserPayment.create(payment);
      })
    );
  }

  @discourseComputed("amount")
  amountDollars(amount) {
    return parseFloat(amount / 100).toFixed(2);
  }
}
