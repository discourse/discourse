/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

@tagName("")
export default class CreateCouponForm extends Component {
  discountType = "amount";
  discount = null;
  promoCode = null;
  active = false;

  @computed
  get discountTypes() {
    return [
      { id: "amount", name: "Amount" },
      { id: "percent", name: "Percent" },
    ];
  }

  @action
  createNewCoupon() {
    const createParams = {
      promo: this.promoCode,
      discount_type: this.discountType,
      discount: this.discount,
      active: this.active,
    };

    this.create(createParams);
  }

  @action
  cancelCreate() {
    this.cancel();
  }

  <template>
    <div class="create-coupon-form" ...attributes>
      <form class="form-horizontal">
        <p>
          <label for="promo_code">
            {{i18n "discourse_subscriptions.admin.coupons.promo_code"}}
          </label>
          <input
            name="promo_code"
            type="text"
            value={{this.promoCode}}
            {{on "input" (withEventValue (fn (mut this.promoCode)))}}
          />
        </p>

        <p>
          <label for="amount">
            {{i18n "discourse_subscriptions.admin.coupons.discount"}}
          </label>
          <ComboBox
            @content={{this.discountTypes}}
            @onChange={{fn (mut this.discountType)}}
            @value={{this.discountType}}
          />
          <input
            class="discount-amount"
            name="amount"
            type="text"
            value={{this.discount}}
            {{on "input" (withEventValue (fn (mut this.discount)))}}
          />
        </p>

        <p>
          <label for="active">
            {{i18n "discourse_subscriptions.admin.coupons.active"}}
          </label>
          <Input name="active" @checked={{this.active}} @type="checkbox" />
        </p>
      </form>

      <DButton
        class="btn-primary btn btn-icon"
        @action={{this.createNewCoupon}}
        @icon="plus"
        @label="discourse_subscriptions.admin.coupons.create"
        @title="discourse_subscriptions.admin.coupons.create"
      />

      <DButton
        class="btn btn-icon"
        label="cancel"
        @action={{this.cancelCreate}}
        @icon="xmark"
        @title="cancel"
      />
    </div>
  </template>
}
