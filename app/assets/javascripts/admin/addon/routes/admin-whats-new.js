import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminWhatsNew extends DiscourseRoute {
  @service currentUser;

  titleToken() {
    return I18n.t("admin.dashboard.new_features.title");
  }

  activate() {
    this.currentUser.set("has_unseen_features", false);
  }
}
