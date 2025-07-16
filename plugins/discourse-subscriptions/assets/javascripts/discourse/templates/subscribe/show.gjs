import { Input } from "@ember/component";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import htmlSafe from "discourse/helpers/html-safe";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { i18n } from "discourse-i18n";
import LoginRequired from "../../components/login-required";
import PaymentOptions from "../../components/payment-options";
import SubscribeCaProvinceSelect from "../../components/subscribe-ca-province-select";
import SubscribeCard from "../../components/subscribe-card";
import SubscribeCountrySelect from "../../components/subscribe-country-select";
import SubscribeUsStateSelect from "../../components/subscribe-us-state-select";

export default RouteTemplate(
  <template>
    <div class="discourse-subscriptions-section-columns">
      <div class="section-column discourse-subscriptions-confirmation-billing">
        <h2>
          {{@controller.model.product.name}}
        </h2>

        <hr />

        <p>
          {{htmlSafe @controller.model.product.description}}
        </p>
      </div>

      <div class="section-column">
        {{#if @controller.canPurchase}}
          <h2>
            {{i18n "discourse_subscriptions.subscribe.card.title"}}
          </h2>

          <hr />

          <PaymentOptions
            @plans={{@controller.model.plans}}
            @selectedPlan={{@controller.selectedPlan}}
          />

          <hr />

          <SubscribeCard @cardElement={{@controller.cardElement}} />

          {{#if @controller.loading}}
            {{loadingSpinner}}
          {{else if @controller.isAnonymous}}
            <LoginRequired />
          {{else}}
            <Input
              @type="text"
              name="cardholder_name"
              placeholder={{i18n
                "discourse_subscriptions.subscribe.cardholder_name"
              }}
              @value={{@controller.cardholderName}}
              class="subscribe-name"
            />
            <div class="address-fields">
              <SubscribeCountrySelect
                @value={{@controller.cardholderAddress.country}}
                @onChange={{@controller.changeCountry}}
              />
              <Input
                @type="text"
                name="cardholder_postal_code"
                placeholder={{i18n
                  "discourse_subscriptions.subscribe.cardholder_address.postal_code"
                }}
                @value={{@controller.cardholderAddress.postalCode}}
                class="subscribe-address-postal-code"
              />
            </div>
            <Input
              @type="text"
              name="cardholder_line1"
              placeholder={{i18n
                "discourse_subscriptions.subscribe.cardholder_address.line1"
              }}
              @value={{@controller.cardholderAddress.line1}}
              class="subscribe-address-line1"
            />
            <div class="address-fields">
              <Input
                @type="text"
                name="cardholder_city"
                placeholder={{i18n
                  "discourse_subscriptions.subscribe.cardholder_address.city"
                }}
                @value={{@controller.cardholderAddress.city}}
                class="subscribe-address-city"
              />
              {{#if @controller.isCountryUS}}
                <SubscribeUsStateSelect
                  @value={{@controller.cardholderAddress.state}}
                  @onChange={{@controller.changeState}}
                />
              {{else if @controller.isCountryCA}}
                <SubscribeCaProvinceSelect
                  @value={{@controller.cardholderAddress.state}}
                  @onChange={{@controller.changeState}}
                />
              {{else}}
                <Input
                  @type="text"
                  name="cardholder_state"
                  placeholder={{i18n
                    "discourse_subscriptions.subscribe.cardholder_address.state"
                  }}
                  @value={{@controller.cardholderAddress.state}}
                  class="subscribe-address-state"
                />
              {{/if}}
            </div>

            <Input
              @type="text"
              name="promo_code"
              placeholder={{i18n
                "discourse_subscriptions.subscribe.promo_code"
              }}
              @value={{@controller.promoCode}}
              class="subscribe-promo-code"
            />

            <DButton
              @disabled={{@controller.loading}}
              @action={{@controller.stripePaymentHandler}}
              class="btn btn-primary btn-payment"
              @label="discourse_subscriptions.plans.payment_button"
            />
          {{/if}}
        {{else}}
          <h2>{{i18n
              "discourse_subscriptions.subscribe.already_purchased"
            }}</h2>

          <LinkTo
            @route="user.billing.subscriptions"
            @model={{@controller.currentUser.username}}
            class="btn btn-primary"
          >
            {{i18n "discourse_subscriptions.subscribe.go_to_billing"}}
          </LinkTo>
        {{/if}}
      </div>
    </div>
  </template>
);
