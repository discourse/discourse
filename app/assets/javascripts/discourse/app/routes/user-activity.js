import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserActivity extends DiscourseRoute {
  @service router;

  model() {
    let user = this.modelFor("user");
    if (user.get("profile_hidden")) {
      return this.router.replaceWith("user.profile-hidden");
    }

    return user;
  }

  setupController(controller, user) {
    this.controllerFor("user-activity").set("model", user);
  }

  titleToken() {
    return i18n("user.activity_stream");
  }
}
