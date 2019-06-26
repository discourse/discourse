import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  secondFactorMethod: SECOND_FACTOR_METHODS.TOTP,
  lockImageUrl: Discourse.getURL("/images/lock.svg"),
  actions: {
    finishLogin() {
      ajax({
        url: `/session/email-login/${this.model.token}`,
        type: "POST",
        data: {
          second_factor_token: this.secondFactorToken,
          second_factor_method: this.secondFactorMethod
        }
      })
        .then(result => {
          if (result.success) {
            DiscourseURL.redirectTo("/");
          } else {
            this.set("model.error", result.error);
          }
        })
        .catch(popupAjaxError);
    }
  }
});
