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
    if (model.security_key_required) {
      method = SECOND_FACTOR_METHODS.SECURITY_KEY;
    } else if (model.backup_codes_enabled && !model.totp_enabled) {
      method = SECOND_FACTOR_METHODS.BACKUP_CODE;
    }
    controller.set("secondFactorMethod", method);
  }
}
