import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminWhatsNew extends DiscourseRoute {
  @service currentUser;

  activate() {
    this.currentUser.set("has_unseen_features", false);
  }
}
