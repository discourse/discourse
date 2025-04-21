import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class ActivateAccountRoute extends DiscourseRoute {
  titleToken() {
    return i18n("login.activate_account");
  }
}
