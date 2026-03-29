import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserActivityReactions extends DiscourseRoute {
  @service router;

  redirect() {
    this.router.replaceWith("userActivity.appreciations", {
      queryParams: { types: "reaction" },
    });
  }
}
