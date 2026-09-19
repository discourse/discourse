import Controller from "@ember/controller";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class SubscriptionsController extends Controller {
  @service currentUser;

  init() {
    super.init(...arguments);
    if (this.currentUser) {
      this.currentUser
        .checkEmail()
        .then(() => this.set("email", this.currentUser.email));
    }
  }

  @computed(
    "email",
    "currentUser.discourse_subscriptions_checkout_session_user_reference"
  )
  get pricingTable() {
    const pricingTableId =
      this.siteSettings.discourse_subscriptions_pricing_table_id;
    const publishableKey = this.siteSettings.discourse_subscriptions_public_key;
    const pricingTableEnabled =
      this.siteSettings.discourse_subscriptions_pricing_table_enabled;
    const clientReferenceId =
      this.currentUser?.discourse_subscriptions_checkout_session_user_reference;

    if (!pricingTableEnabled || !pricingTableId || !publishableKey) {
      return i18n("discourse_subscriptions.subscribe.no_products");
    }

    if (this.currentUser) {
      if (!this.email || !clientReferenceId) {
        return "";
      }

      return trustHTML(`<stripe-pricing-table
                pricing-table-id="${pricingTableId}"
                publishable-key="${publishableKey}"
                customer-email="${this.email}"
                client-reference-id="${clientReferenceId}"></stripe-pricing-table>`);
    } else {
      return trustHTML(`<stripe-pricing-table
                pricing-table-id="${pricingTableId}"
                publishable-key="${publishableKey}"
                ></stripe-pricing-table>`);
    }
  }
}
