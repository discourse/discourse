import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class ActivateAccountRoute extends DiscourseRoute {
  titleToken() {
    return I18n.t("login.activate_account");
  }
}
