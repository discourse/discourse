/* global Stripe */
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { not } from "@ember/object/computed";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import Subscription from "discourse/plugins/discourse-subscriptions/discourse/models/subscription";
import Transaction from "discourse/plugins/discourse-subscriptions/discourse/models/transaction";

export default class SubscribeShowController extends Controller {
  @service dialog;
  @service router;

  selectedPlan = null;
  promoCode = null;
  cardholderName = null;
  cardholderAddress = {
    line1: null,
    city: null,
    state: null,
    country: null,
    postalCode: null,
  };

  @not("currentUser") isAnonymous;

  isCountryUS = false;
  isCountryCA = false;

  init() {
    super.init(...arguments);
    this.set(
      "stripe",
      Stripe(this.siteSettings.discourse_subscriptions_public_key)
    );
    const elements = this.get("stripe").elements();

    this.set("cardElement", elements.create("card", { hidePostalCode: true }));

    this.set("isCountryUS", this.cardholderAddress.country === "US");
    this.set("isCountryCA", this.cardholderAddress.country === "CA");
  }

  alert(path) {
    this.dialog.alert(i18n(`discourse_subscriptions.${path}`));
  }

  @discourseComputed("model.product.repurchaseable", "model.product.subscribed")
  canPurchase(repurchaseable, subscribed) {
    if (!repurchaseable && subscribed) {
      return false;
    }

    return true;
  }

  createSubscription(plan) {
    return this.stripe
      .createToken(this.get("cardElement"), {
        name: this.cardholderName, // Recommended by Stripe
        address_line1: this.cardholderAddress.line1 ?? "",
        address_city: this.cardholderAddress.city ?? "",
        address_state: this.cardholderAddress.state ?? "",
        address_zip: this.cardholderAddress.postalCode ?? "",
        address_country: this.cardholderAddress.country, // Recommended by Stripe
      })
      .then((result) => {
        if (result.error) {
          this.set("loading", false);
          return result;
        } else {
          const subscription = Subscription.create({
            source: result.token.id,
            plan: plan.get("id"),
            promo: this.promoCode,
            cardholderName: this.cardholderName,
            cardholderAddress: this.cardholderAddress,
          });

          return subscription.save();
        }
      });
  }

  handleAuthentication(plan, transaction) {
    return this.stripe
      .confirmCardPayment(transaction.payment_intent.client_secret)
      .then((result) => {
        if (
          result.paymentIntent &&
          result.paymentIntent.status === "succeeded"
        ) {
          return result;
        } else {
          this.set("loading", false);
          this.dialog.alert(result.error.message || result.error);
          return result;
        }
      });
  }

  _advanceSuccessfulTransaction(plan) {
    this.alert("plans.success");
    this.set("loading", false);

    this.router.transitionTo(
      plan.type === "recurring"
        ? "user.billing.subscriptions"
        : "user.billing.payments",
      this.currentUser.username.toLowerCase()
    );
  }

  @action
  changeCountry(country) {
    this.set("cardholderAddress.country", country);
    this.set("isCountryUS", country === "US");
    this.set("isCountryCA", country === "CA");
  }

  @action
  changeState(stateOrProvince) {
    this.set("cardholderAddress.state", stateOrProvince);
  }

  @action
  stripePaymentHandler() {
    this.set("loading", true);
    const plan = this.get("model.plans")
      .filterBy("id", this.selectedPlan)
      .get("firstObject");
    const cardholderAddress = this.cardholderAddress;
    const cardholderName = this.cardholderName;

    if (!plan) {
      this.alert("plans.validate.payment_options.required");
      this.set("loading", false);
      return;
    }

    if (!cardholderName) {
      this.alert("subscribe.invalid_cardholder_name");
      this.set("loading", false);
      return;
    }

    if (!cardholderAddress.country) {
      this.alert("subscribe.invalid_cardholder_country");
      this.set("loading", false);
      return;
    }

    if (cardholderAddress.country === "US" && !cardholderAddress.state) {
      this.alert("subscribe.invalid_cardholder_state");
      this.set("loading", false);
      return;
    }

    if (cardholderAddress.country === "CA" && !cardholderAddress.state) {
      this.alert("subscribe.invalid_cardholder_province");
      this.set("loading", false);
      return;
    }

    let transaction = this.createSubscription(plan);

    transaction
      .then((result) => {
        if (result.error) {
          this.dialog.alert(result.error.message || result.error);
        } else if (result.status === "incomplete" || result.status === "open") {
          const transactionId = result.id;
          const planId = this.selectedPlan;
          this.handleAuthentication(plan, result).then(
            (authenticationResult) => {
              if (authenticationResult && !authenticationResult.error) {
                return Transaction.finalize(transactionId, planId).then(() => {
                  this._advanceSuccessfulTransaction(plan);
                });
              }
            }
          );
        } else {
          this._advanceSuccessfulTransaction(plan);
        }
      })
      .catch((result) => {
        this.dialog.alert(
          result.jqXHR.responseJSON.errors[0] || result.errorThrown
        );
        this.set("loading", false);
      });
  }
}
