/* global Stripe */
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class UserBillingSubscriptionsCardController extends Controller {
  @service dialog;

  loading = false;
  saved = false;

  init() {
    super.init(...arguments);
    this.set(
      "stripe",
      Stripe(this.siteSettings.discourse_subscriptions_public_key)
    );
    const elements = this.get("stripe").elements();
    this.set("cardElement", elements.create("card", { hidePostalCode: true }));
  }

  @action
  async updatePaymentMethod() {
    this.set("loading", true);
    this.set("saved", false);

    const paymentMethodObject = await this.stripe.createPaymentMethod({
      type: "card",
      card: this.cardElement,
    });

    if (paymentMethodObject.error) {
      this.dialog.alert(
        paymentMethodObject.error?.message || i18n("generic_error")
      );
      this.set("loading", false);
      return;
    }

    const paymentMethod = paymentMethodObject.paymentMethod.id;

    try {
      await ajax(`/s/user/subscriptions/${this.model}`, {
        method: "PUT",
        data: {
          payment_method: paymentMethod,
        },
      });
      this.set("saved", true);
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.set("loading", false);
      this.cardElement?.clear();
    }
  }
}
