import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";
import I18n from "discourse-i18n";

export default class Preferences extends RestrictedUserRoute {
  @service router;

  model() {
    return this.modelFor("user");
  }

  titleToken() {
    let controller = this.controllerFor(this.router.currentRouteName);
    let subpageTitle = controller?.subpageTitle;
    return subpageTitle
      ? `${subpageTitle} - ${I18n.t("user.preferences")}`
      : I18n.t("user.preferences");
  }
}
