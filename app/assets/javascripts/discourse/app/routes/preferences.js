import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";
import { i18n } from "discourse-i18n";

export default class Preferences extends RestrictedUserRoute {
  @service router;

  model() {
    return this.modelFor("user");
  }

  titleToken() {
    let controller = this.controllerFor(this.router.currentRouteName);
    let subpageTitle = controller?.subpageTitle;
    return subpageTitle
      ? `${subpageTitle} - ${i18n("user.preferences.title")}`
      : i18n("user.preferences.title");
  }
}
