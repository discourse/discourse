import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";

const RECURRING = "recurring";
const ONE_TIME = "one_time";

export default class AdminPluginsDiscourseSubscriptionsProductsShowPlansShowController extends Controller {
  // Also defined in settings.
  @alias("model.plan.currency") selectedCurrency;
  @alias("model.plan.interval") selectedInterval;

  @discourseComputed("model.plan.metadata.group_name")
  selectedGroup(groupName) {
    return groupName || "no-group";
  }

  @discourseComputed("model.groups")
  availableGroups(groups) {
    return [
      {
        id: null,
        name: "no-group",
      },
      ...groups,
    ];
  }

  @discourseComputed
  currencies() {
    return [
      { id: "AUD", name: "AUD" },
      { id: "CAD", name: "CAD" },
      { id: "EUR", name: "EUR" },
      { id: "GBP", name: "GBP" },
      { id: "USD", name: "USD" },
      { id: "INR", name: "INR" },
      { id: "BRL", name: "BRL" },
      { id: "DKK", name: "DKK" },
      { id: "SGD", name: "SGD" },
      { id: "JPY", name: "JPY" },
      { id: "ZAR", name: "ZAR" },
      { id: "CHF", name: "CHF" },
      { id: "PLN", name: "PLN" },
      { id: "CZK", name: "CZK" },
      { id: "SEK", name: "SEK" },
    ];
  }

  @discourseComputed
  availableIntervals() {
    return [
      { id: "day", name: "day" },
      { id: "week", name: "week" },
      { id: "month", name: "month" },
      { id: "year", name: "year" },
    ];
  }

  @discourseComputed("model.plan.isNew")
  planFieldDisabled(isNew) {
    return !isNew;
  }

  @discourseComputed("model.product.id")
  productId(id) {
    return id;
  }

  redirect(product_id) {
    DiscourseURL.redirectTo(
      `/admin/plugins/discourse-subscriptions/products/${product_id}`
    );
  }

  @action
  changeRecurring() {
    const recurring = this.get("model.plan.isRecurring");
    this.set("model.plan.type", recurring ? ONE_TIME : RECURRING);
    this.set("model.plan.isRecurring", !recurring);
  }

  @action
  createPlan() {
    if (this.model.plan.metadata.group_name === "no-group") {
      this.set("model.plan.metadata.group_name", null);
    }
    this.get("model.plan")
      .save()
      .then(() => this.redirect(this.productId))
      .catch(popupAjaxError);
  }

  @action
  updatePlan() {
    if (this.model.plan.metadata.group_name === "no-group") {
      this.set("model.plan.metadata.group_name", null);
    }
    this.get("model.plan")
      .update()
      .then(() => this.redirect(this.productId))
      .catch(popupAjaxError);
  }
}
