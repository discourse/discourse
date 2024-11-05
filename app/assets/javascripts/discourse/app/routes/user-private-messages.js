import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserPrivateMessages extends DiscourseRoute {
  @service composer;

  templateName = "user/messages";

  afterModel() {
    this.pmTopicTrackingState.startTracking();
  }

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
