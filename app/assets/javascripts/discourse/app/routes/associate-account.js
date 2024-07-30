import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import AssociateAccountConfirm from "discourse/components/modal/associate-account-confirm";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import cookie from "discourse/lib/cookie";
import DiscourseRoute from "discourse/routes/discourse";

export default class AssociateAccount extends DiscourseRoute {
  @service router;
  @service currentUser;
  @service modal;

  beforeModel(transition) {
    if (!this.currentUser) {
      cookie("destination_url", transition.intent.url);
      return this.router.replaceWith("login");
    }
    const params = this.paramsFor("associate-account");
    this.redirectToAccount(params);
  }

  @action
  async redirectToAccount(params) {
    await this.router
      .replaceWith(`preferences.account`, this.currentUser)
      .followRedirects();
    next(() => this.showAssociateAccount(params));
  }

  @action
  async showAssociateAccount(params) {
    try {
      const model = await ajax(
        `/associate/${encodeURIComponent(params.token)}.json`
      );
      this.modal.show(AssociateAccountConfirm, { model });
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
