import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class CreateCouponForm extends Component {
  discountType = "amount";
  discount = null;
  promoCode = null;
  active = false;

  @discourseComputed
  discountTypes() {
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
    <div class="create-coupon-form">
      <form class="form-horizontal">
        <p>
          <label for="promo_code">
            {{i18n "discourse_subscriptions.admin.coupons.promo_code"}}
          </label>
          <Input @type="text" name="promo_code" @value={{this.promoCode}} />
        </p>

        <p>
          <label for="amount">
            {{i18n "discourse_subscriptions.admin.coupons.discount"}}
          </label>
          <ComboBox
            @content={{this.discountTypes}}
            @value={{this.discountType}}
            @onChange={{fn (mut this.discountType)}}
          />
          <Input
            class="discount-amount"
            @type="text"
            name="amount"
            @value={{this.discount}}
          />
        </p>

        <p>
          <label for="active">
            {{i18n "discourse_subscriptions.admin.coupons.active"}}
          </label>
          <Input @type="checkbox" name="active" @checked={{this.active}} />
        </p>
      </form>

      <DButton
        @action={{this.createNewCoupon}}
        @label="discourse_subscriptions.admin.coupons.create"
        @title="discourse_subscriptions.admin.coupons.create"
        @icon="plus"
        class="btn-primary btn btn-icon"
      />

      <DButton
        @action={{this.cancelCreate}}
        label="cancel"
        @title="cancel"
        @icon="xmark"
        class="btn btn-icon"
      />
    </div>
  </template>
}
