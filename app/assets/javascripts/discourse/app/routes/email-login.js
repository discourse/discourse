import { ajax } from "discourse/lib/ajax";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("login.title");
  },

  model(params) {
    return ajax(`/session/email-login/${params.token}.json`);
  },

  setupController(controller, model) {
    this._super.apply(this, arguments);

    controller.set(
      "secondFactorMethod",
      model.security_key_required
        ? SECOND_FACTOR_METHODS.SECURITY_KEY
        : SECOND_FACTOR_METHODS.TOTP
    );
  },
});
