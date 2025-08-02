import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AccountCreated extends DiscourseRoute {
  titleToken() {
    return i18n("create_account.activation_title");
  }

  setupController(controller) {
    controller.set("accountCreated", PreloadStore.get("accountCreated"));
  }
}
