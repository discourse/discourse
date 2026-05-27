import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserActivityRewind extends DiscourseRoute {
  @service currentUser;
  @service router;

  templateName = "user/rewind";

  beforeModel() {
    if (!this.currentUser) {
      return this.router.transitionTo("discovery.latest");
    }
  }
}
