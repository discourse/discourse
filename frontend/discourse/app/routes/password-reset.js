import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class PasswordReset extends DiscourseRoute {
  titleToken() {
    return i18n("login.reset_password");
  }

  model() {
    if (PreloadStore.get("password_reset")) {
      return PreloadStore.getAndRemove("password_reset");
    }

    return ajax("/u/password-reset.json");
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.initSelectedSecondFactorMethod();
  }
}
