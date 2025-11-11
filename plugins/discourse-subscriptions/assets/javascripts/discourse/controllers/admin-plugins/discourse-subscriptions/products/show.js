import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsDiscourseSubscriptionsProductsShowController extends Controller {
  @service router;

  @action
  cancelProduct() {
    this.router.transitionTo("adminPlugins.discourse-subscriptions.products");
  }

  @action
  createProduct() {
    this.get("model.product")
      .save()
      .then((product) => {
        this.router.transitionTo(
          "adminPlugins.discourse-subscriptions.products.show",
          product.id
        );
      })
      .catch(popupAjaxError);
  }

  @action
  updateProduct() {
    this.get("model.product")
      .update()
      .then(() => {
        this.router.transitionTo(
          "adminPlugins.discourse-subscriptions.products"
        );
      })
      .catch(popupAjaxError);
  }
}
