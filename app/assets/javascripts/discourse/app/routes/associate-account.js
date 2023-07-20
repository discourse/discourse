import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { next } from "@ember/runloop";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import cookie from "discourse/lib/cookie";

export default DiscourseRoute.extend({
  beforeModel(transition) {
    if (!this.currentUser) {
      cookie("destination_url", transition.intent.url);
      return this.replaceWith("login");
    }
    const params = this.paramsFor("associate-account");
    this.replaceWith(`preferences.account`, this.currentUser).then(() =>
      next(() =>
        ajax(`/associate/${encodeURIComponent(params.token)}.json`)
          .then((model) => showModal("associate-account-confirm", { model }))
          .catch(popupAjaxError)
      )
    );
  },
});
