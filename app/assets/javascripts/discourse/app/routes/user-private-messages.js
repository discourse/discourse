import { action } from "@ember/object";
import { service } from "@ember/service";
import Composer from "discourse/models/composer";
import Draft from "discourse/models/draft";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserPrivateMessages extends DiscourseRoute {
  @service composer;

  templateName = "user/messages";

  afterModel() {
    this.pmTopicTrackingState.startTracking();
  }

  setupController() {
    super.setupController(...arguments);

    if (this.currentUser) {
      Draft.get("new_private_message").then((data) => {
        if (data.draft) {
          this.composer.open({
            draft: data.draft,
            draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
            ignoreIfChanged: true,
            draftSequence: data.draft_sequence,
          });
        }
      });
    }
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
