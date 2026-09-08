import { Input } from "@ember/component";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";
import LoginRequired from "../../components/login-required";
import PaymentOptions from "../../components/payment-options";
import SubscribeCaProvinceSelect from "../../components/subscribe-ca-province-select";
import SubscribeCard from "../../components/subscribe-card";
import SubscribeCountrySelect from "../../components/subscribe-country-select";
import SubscribeUsStateSelect from "../../components/subscribe-us-state-select";

export default <template>
  <div class="discourse-subscriptions-section-columns">
    <div class="section-column discourse-subscriptions-confirmation-billing">
      <h2>
        {{@controller.model.product.name}}
      </h2>

      <hr />

      <p>
        {{trustHTML @controller.model.product.description}}
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
          {{dLoadingSpinner}}
        {{else if @controller.isAnonymous}}
          <LoginRequired />
        {{else}}
          <Input
            class="subscribe-name"
            name="cardholder_name"
            placeholder={{i18n
              "discourse_subscriptions.subscribe.cardholder_name"
            }}
            @type="text"
            @value={{@controller.cardholderName}}
          />
          <div class="address-fields">
            <SubscribeCountrySelect
              @onChange={{@controller.changeCountry}}
              @value={{@controller.cardholderAddress.country}}
            />
            <Input
              class="subscribe-address-postal-code"
              name="cardholder_postal_code"
              placeholder={{i18n
                "discourse_subscriptions.subscribe.cardholder_address.postal_code"
              }}
              @type="text"
              @value={{@controller.cardholderAddress.postalCode}}
            />
          </div>
          <Input
            class="subscribe-address-line1"
            name="cardholder_line1"
            placeholder={{i18n
              "discourse_subscriptions.subscribe.cardholder_address.line1"
            }}
            @type="text"
            @value={{@controller.cardholderAddress.line1}}
          />
          <div class="address-fields">
            <Input
              class="subscribe-address-city"
              name="cardholder_city"
              placeholder={{i18n
                "discourse_subscriptions.subscribe.cardholder_address.city"
              }}
              @type="text"
              @value={{@controller.cardholderAddress.city}}
            />
            {{#if @controller.isCountryUS}}
              <SubscribeUsStateSelect
                @onChange={{@controller.changeState}}
                @value={{@controller.cardholderAddress.state}}
              />
            {{else if @controller.isCountryCA}}
              <SubscribeCaProvinceSelect
                @onChange={{@controller.changeState}}
                @value={{@controller.cardholderAddress.state}}
              />
            {{else}}
              <Input
                class="subscribe-address-state"
                name="cardholder_state"
                placeholder={{i18n
                  "discourse_subscriptions.subscribe.cardholder_address.state"
                }}
                @type="text"
                @value={{@controller.cardholderAddress.state}}
              />
            {{/if}}
          </div>

          <Input
            class="subscribe-promo-code"
            name="promo_code"
            placeholder={{i18n "discourse_subscriptions.subscribe.promo_code"}}
            @type="text"
            @value={{@controller.promoCode}}
          />

          <DButton
            class="btn btn-primary btn-payment"
            @action={{@controller.stripePaymentHandler}}
            @disabled={{@controller.loading}}
            @label="discourse_subscriptions.plans.payment_button"
          />
        {{/if}}
      {{else}}
        <h2>{{i18n "discourse_subscriptions.subscribe.already_purchased"}}</h2>

        <LinkTo
          class="btn btn-primary"
          @model={{@controller.currentUser.username}}
          @route="user.billing.subscriptions"
        >
          {{i18n "discourse_subscriptions.subscribe.go_to_billing"}}
        </LinkTo>
      {{/if}}
    </div>
  </div>
</template>
