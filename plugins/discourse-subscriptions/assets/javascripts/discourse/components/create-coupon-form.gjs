import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class CreateCouponForm extends Component {
  @tracked discountType = "amount";
  @tracked discount = null;
  @tracked promoCode = null;
  @tracked active = false;

  discountTypes = [
    { id: "amount", name: "Amount" },
    { id: "percent", name: "Percent" },
  ];

  @action
  createNewCoupon() {
    const createParams = {
      promo: this.promoCode,
      discount_type: this.discountType,
      discount: this.discount,
      active: this.active,
    };

    this.args.create(createParams);
  }

  @action
  cancelCreate() {
    this.args.cancel();
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
