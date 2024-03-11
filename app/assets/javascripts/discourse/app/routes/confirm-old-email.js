import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class ConfirmOldEmailRoute extends DiscourseRoute {
  titleToken() {
    return I18n.t("user.change_email.title");
  }

  model(params) {
    return ajax(`/u/confirm-old-email/${params.token}.json`);
  }
}
