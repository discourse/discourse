import { next } from "@ember/runloop";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import showModal from "discourse/lib/show-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default DiscourseRoute.extend({
  beforeModel() {
    const params = this.paramsFor("associate-account");
    this.replaceWith(`preferences.account`, this.currentUser).then(() =>
      next(() =>
        ajax(`/associate/${encodeURIComponent(params.token)}.json`)
          .then(model => showModal("associate-account-confirm", { model }))
          .catch(popupAjaxError)
      )
    );
  }
});
