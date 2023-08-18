import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import cookie from "discourse/lib/cookie";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { next } from "@ember/runloop";

export default DiscourseRoute.extend({
  router: service(),
  currentUser: service(),

  beforeModel(transition) {
    if (!this.currentUser) {
      cookie("destination_url", transition.intent.url);
      return this.router.replaceWith("login");
    }
    const params = this.paramsFor("associate-account");
    this.redirectToAccount(params);
  },

  @action
  async redirectToAccount(params) {
    await this.router
      .replaceWith(`preferences.account`, this.currentUser)
      .followRedirects();
    next(() => this.showAssociateAccount(params));
  },

  @action
  async showAssociateAccount(params) {
    try {
      const model = await ajax(
        `/associate/${encodeURIComponent(params.token)}.json`
      );
      showModal("associate-account-confirm", { model });
    } catch {
      popupAjaxError;
    }
  },
});
