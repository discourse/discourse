import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserSummary extends DiscourseRoute {
  @service router;

  model() {
    const user = this.modelFor("user");
    if (user.get("profile_hidden")) {
      return this.router.replaceWith("user.profile-hidden");
    }

    return user.summary();
  }

  titleToken() {
    return i18n("user.summary.title");
  }
}
