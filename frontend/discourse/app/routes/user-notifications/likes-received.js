import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserNotificationsLikesReceived extends DiscourseRoute {
  @service router;

  redirect() {
    this.router.replaceWith("userNotifications.appreciationsReceived", {
      queryParams: { types: "like" },
    });
  }
}
