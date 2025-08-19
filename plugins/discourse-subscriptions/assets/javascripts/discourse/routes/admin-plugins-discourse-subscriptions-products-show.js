import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { hash } from "rsvp";
import { i18n } from "discourse-i18n";
import AdminPlan from "discourse/plugins/discourse-subscriptions/discourse/models/admin-plan";
import AdminProduct from "discourse/plugins/discourse-subscriptions/discourse/models/admin-product";

export default class AdminPluginsDiscourseSubscriptionsProductsShowRoute extends Route {
  @service dialog;

  model(params) {
    const product_id = params["product-id"];
    let product;
    let plans = [];

    if (product_id === "new") {
      product = AdminProduct.create({ active: false, isNew: true });
    } else {
      product = AdminProduct.find(product_id);
      plans = AdminPlan.findAll({ product_id });
    }

    return hash({ plans, product });
  }

  @action
  destroyPlan(plan) {
    this.dialog.yesNoConfirm({
      message: i18n(
        "discourse_subscriptions.admin.plans.operations.destroy.confirm"
      ),
      didConfirm: () => {
        plan
          .destroy()
          .then(() => {
            this.controllerFor("adminPluginsDiscourseSubscriptionsProductsShow")
              .get("model.plans")
              .removeObject(plan);
          })
          .catch((data) =>
            this.dialog.alert(data.jqXHR.responseJSON.errors.join("\n"))
          );
      },
    });
  }
}
