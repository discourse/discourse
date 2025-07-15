import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import AdminCancelSubscription from "../components/modal/admin-cancel-subscription";
import AdminSubscription from "../models/admin-subscription";

export default class AdminPluginsDiscourseSubscriptionsSubscriptionsController extends Controller {
  @service modal;
  @service dialog;

  loading = false;

  @action
  showCancelModal(subscription) {
    this.modal.show(AdminCancelSubscription, {
      model: {
        subscription,
        cancelSubscription: this.cancelSubscription,
      },
    });
  }

  @action
  loadMore() {
    if (!this.loading && this.model.has_more) {
      this.set("loading", true);

      return AdminSubscription.loadMore(this.model.last_record).then(
        (result) => {
          const updated = this.model.data.concat(result.data);
          this.set("model", result);
          this.set("model.data", updated);
          this.set("loading", false);
        }
      );
    }
  }

  @action
  cancelSubscription(model) {
    const subscription = model.subscription;
    const refund = model.refund;
    const closeModal = model.closeModal;

    subscription.set("loading", true);
    subscription
      .destroy(refund)
      .then((result) => {
        subscription.set("status", result.status);
        this.dialog.alert(i18n("discourse_subscriptions.admin.canceled"));
      })
      .catch((data) =>
        this.dialog.alert(data.jqXHR.responseJSON.errors.join("\n"))
      )
      .finally(() => {
        subscription.set("loading", false);
        closeModal();
      });
  }
}
