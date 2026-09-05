import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class ActivateAccountRoute extends DiscourseRoute {
  titleToken() {
    return i18n("login.activate_account");
  }

  model() {
    if (PreloadStore.get("account_activation")) {
      return PreloadStore.getAndRemove("account_activation");
    }

    return ajax("/u/activate-account.json");
  }
}
