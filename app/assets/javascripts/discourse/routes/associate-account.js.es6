import { ajax } from "discourse/lib/ajax";
import showModal from "discourse/lib/show-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Discourse.Route.extend({
  beforeModel() {
    const params = this.paramsFor("associate-account");
    this.replaceWith(`preferences.account`, this.currentUser).then(() =>
      Ember.run.next(() =>
        ajax(`/associate/${encodeURIComponent(params.token)}`)
          .then(model => showModal("associate-account-confirm", { model }))
          .catch(popupAjaxError)
      )
    );
  }
});
