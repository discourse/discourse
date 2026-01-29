import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigUpcomingChangesRoute extends DiscourseRoute {
  @service currentUser;

  titleToken() {
    return i18n("admin.config.upcoming_changes.title");
  }

  model() {
    return ajax("/admin/config/upcoming-changes").then(
      (result) => result.upcoming_changes
    );
  }

  activate() {
    this.currentUser.set("has_new_upcoming_changes", false);
  }
}
