import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsDiscourseSubscriptionsPlansShowController extends Controller {
  @service router;

  @action
  createPlan() {
    if (this.get("model.plan.product_id") === undefined) {
      const productID = this.get("model.products.firstObject.id");
      this.set("model.plan.product_id", productID);
    }

    this.get("model.plan")
      .save()
      .then(() => {
        this.router.transitionTo("adminPlugins.discourse-subscriptions.plans");
      })
      .catch(popupAjaxError);
  }
}
