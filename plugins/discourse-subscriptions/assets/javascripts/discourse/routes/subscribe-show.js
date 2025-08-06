import Route from "@ember/routing/route";
import Plan from "discourse/plugins/discourse-subscriptions/discourse/models/plan";
import Product from "discourse/plugins/discourse-subscriptions/discourse/models/product";
import Subscription from "discourse/plugins/discourse-subscriptions/discourse/models/subscription";

export default class SubscribeShowRoute extends Route {
  model(params) {
    const product_id = params["subscription-id"];

    return Subscription.show(product_id).then((result) => {
      result.product = Product.create(result.product);
      result.plans = result.plans.map((plan) => {
        return Plan.create(plan);
      });

      return result;
    });
  }
}
