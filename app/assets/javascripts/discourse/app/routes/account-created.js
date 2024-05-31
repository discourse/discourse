import PreloadStore from "discourse/lib/preload-store";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AccountCreated extends DiscourseRoute {
  titleToken() {
    return I18n.t("create_account.activation_title");
  }

  setupController(controller) {
    controller.set("accountCreated", PreloadStore.get("accountCreated"));
  }
}
