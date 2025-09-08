import Route from "@ember/routing/route";
import { service } from "@ember/service";
import Product from "discourse/plugins/discourse-subscriptions/discourse/models/product";

export default class SubscribeIndexRoute extends Route {
  @service router;

  model() {
    return Product.findAll();
  }

  afterModel(products) {
    if (products.length === 1) {
      const product = products[0];

      if (this.currentUser && product.subscribed && !product.repurchaseable) {
        this.router.transitionTo(
          "user.billing.subscriptions",
          this.currentUser.username
        );
      } else {
        this.router.transitionTo("subscribe.show", product.id);
      }
    }
  }
}
