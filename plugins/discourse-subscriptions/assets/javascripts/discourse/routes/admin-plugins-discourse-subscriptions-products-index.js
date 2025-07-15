import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import AdminProduct from "discourse/plugins/discourse-subscriptions/discourse/models/admin-product";

export default class AdminPluginsDiscourseSubscriptionsProductsIndexRoute extends Route {
  @service dialog;

  model() {
    return AdminProduct.findAll();
  }

  @action
  destroyProduct(product) {
    this.dialog.yesNoConfirm({
      message: i18n(
        "discourse_subscriptions.admin.products.operations.destroy.confirm"
      ),
      didConfirm: () => {
        return product
          .destroy()
          .then(() => {
            this.controllerFor(
              "adminPluginsDiscourseSubscriptionsProductsIndex"
            )
              .get("model")
              .removeObject(product);
          })
          .catch((data) =>
            this.dialog.alert(data.jqXHR.responseJSON.errors.join("\n"))
          );
      },
    });
  }
}
