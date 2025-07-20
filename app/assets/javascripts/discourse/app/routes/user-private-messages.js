import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserPrivateMessages extends DiscourseRoute {
  @service composer;

  templateName = "user/messages";

  @action
  triggerRefresh() {
    this.refresh();
  }

  @action
  willTransition() {
    super.willTransition(...arguments);
    return true;
  }
}
