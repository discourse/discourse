import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import AdminCoupon from "discourse/plugins/discourse-subscriptions/discourse/models/admin-coupon";

export default class AdminPluginsDiscourseSubscriptionsCouponsController extends Controller {
  creating = null;

  @action
  openCreateForm() {
    this.set("creating", true);
  }

  @action
  closeCreateForm() {
    this.set("creating", false);
  }

  @action
  createNewCoupon(params) {
    AdminCoupon.save(params)
      .then(() => {
        this.send("closeCreateForm");
        this.send("reloadModel");
      })
      .catch(popupAjaxError);
  }

  @action
  deleteCoupon(coupon) {
    AdminCoupon.destroy(coupon)
      .then(() => {
        this.send("reloadModel");
      })
      .catch(popupAjaxError);
  }

  @action
  toggleActive(coupon) {
    const couponData = {
      id: coupon.id,
      active: !coupon.active,
    };
    AdminCoupon.update(couponData)
      .then(() => {
        this.send("reloadModel");
      })
      .catch(popupAjaxError);
  }
}
