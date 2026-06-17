import { ajax } from "discourse/lib/ajax";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class EmailLogin extends DiscourseRoute {
  titleToken() {
    return i18n("login.title");
  }

  model(params) {
    return ajax(`/session/email-login/${params.token}.json`);
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    let method = SECOND_FACTOR_METHODS.TOTP;
    if (model.passkeys_enabled) {
      method = SECOND_FACTOR_METHODS.PASSKEY;
    } else if (model.security_key_required) {
      method = SECOND_FACTOR_METHODS.SECURITY_KEY;
    }
    controller.setProperties({
      secondFactorMethod: method,
      showTokenInput: false,
    });
  }
}
