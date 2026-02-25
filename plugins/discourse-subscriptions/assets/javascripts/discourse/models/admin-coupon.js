import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class AdminCoupon extends EmberObject {
  static list() {
    return ajax("/s/admin/coupons", {
      method: "get",
    }).then((result) => {
      if (result === null) {
        return { unconfigured: true };
      }
      return result.map((coupon) => AdminCoupon.create(coupon));
    });
  }

  static save(params) {
    const data = {
      promo: params.promo,
      discount_type: params.discount_type,
      discount: params.discount,
      active: params.active,
    };

    return ajax("/s/admin/coupons", {
      method: "post",
      data,
    }).then((coupon) => AdminCoupon.create(coupon));
  }

  static update(params) {
    const data = {
      id: params.id,
      active: params.active,
    };

    return ajax("/s/admin/coupons", {
      method: "put",
      data,
    }).then((coupon) => AdminCoupon.create(coupon));
  }

  static destroy(params) {
    const data = {
      coupon_id: params.coupon.id,
    };
    return ajax("/s/admin/coupons", {
      method: "delete",
      data,
    });
  }

  @computed("coupon.amount_off", "coupon.percent_off")
  get discount() {
    if (this.coupon?.amount_off) {
      return `${parseFloat(this.coupon?.amount_off * 0.01).toFixed(2)}`;
    } else if (this.coupon?.percent_off) {
      return `${this.coupon?.percent_off}%`;
    }
  }
}
