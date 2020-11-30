import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { next } from "@ember/runloop";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";

export default DiscourseRoute.extend({
  beforeModel() {
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
