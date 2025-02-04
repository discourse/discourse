import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class ConfirmNewEmailRoute extends DiscourseRoute {
  titleToken() {
    return i18n("user.change_email.title");
  }

  model(params) {
    return ajax(`/u/confirm-new-email/${params.token}.json`);
  }
}
