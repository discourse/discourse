import { ajax } from "discourse/lib/ajax";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class EmailLogin extends DiscourseRoute {
  titleToken() {
    return i18n("login.title");
  }

  model() {
    return ajax("/session/email-login.json");
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    controller.set(
      "secondFactorMethod",
      model.security_key_required
        ? SECOND_FACTOR_METHODS.SECURITY_KEY
        : SECOND_FACTOR_METHODS.TOTP
    );
  }
}
