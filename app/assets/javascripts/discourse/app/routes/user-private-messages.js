import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserPrivateMessages extends DiscourseRoute {
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
