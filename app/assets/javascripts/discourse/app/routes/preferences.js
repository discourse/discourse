import RestrictedUserRoute from "discourse/routes/restricted-user";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default RestrictedUserRoute.extend({
  router: service(),

  model() {
    return this.modelFor("user");
  },

  titleToken() {
    let controller = this.controllerFor(this.router.currentRouteName);
    let subpageTitle = controller?.subpageTitle;
    return subpageTitle
      ? `${subpageTitle} - ${I18n.t("user.preferences")}`
      : I18n.t("user.preferences");
  },
});
