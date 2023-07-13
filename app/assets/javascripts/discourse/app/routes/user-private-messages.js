import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import Draft from "discourse/models/draft";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  templateName: "user/messages",
  composer: service(),

  afterModel() {
    this.pmTopicTrackingState.startTracking();
  },

  setupController() {
    this._super(...arguments);

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
  },

  @action
  triggerRefresh() {
    this.refresh();
  },

  @action
  willTransition() {
    this._super(...arguments);
    return true;
  },
});
