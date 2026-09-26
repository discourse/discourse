import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import CurrentUserService from "discourse/services/current-user";

export default class AdminWhatsNew extends DiscourseRoute {
  @service(() => CurrentUserService) currentUser;

  titleToken() {
    return i18n("admin.dashboard.new_features.title");
  }

  activate() {
    this.currentUser.set("has_unseen_features", false);
  }
}
