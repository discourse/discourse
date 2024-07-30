import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserActivityBookmarksWithReminders extends DiscourseRoute {
  @service router;

  queryParams = {
    q: { replace: true },
  };

  redirect() {
    this.router.transitionTo("userActivity.bookmarks");
  }
}
