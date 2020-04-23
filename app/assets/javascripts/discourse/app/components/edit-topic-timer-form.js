import { equal, or, readOnly } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import {
  PUBLISH_TO_CATEGORY_STATUS_TYPE,
  OPEN_STATUS_TYPE,
  DELETE_STATUS_TYPE,
  REMINDER_TYPE,
  CLOSE_STATUS_TYPE,
  BUMP_TYPE,
  DELETE_REPLIES_TYPE
} from "discourse/controllers/edit-topic-timer";

export default Component.extend({
  selection: readOnly("topicTimer.status_type"),
  autoOpen: equal("selection", OPEN_STATUS_TYPE),
  autoClose: equal("selection", CLOSE_STATUS_TYPE),
  autoDelete: equal("selection", DELETE_STATUS_TYPE),
  autoBump: equal("selection", BUMP_TYPE),
  publishToCategory: equal("selection", PUBLISH_TO_CATEGORY_STATUS_TYPE),
  reminder: equal("selection", REMINDER_TYPE),
  autoDeleteReplies: equal("selection", DELETE_REPLIES_TYPE),
  showTimeOnly: or("autoOpen", "autoDelete", "reminder", "autoBump"),
  showFutureDateInput: or(
    "showTimeOnly",
    "publishToCategory",
    "autoClose",
    "autoDeleteReplies"
  ),

  @discourseComputed("autoDeleteReplies")
  durationType(autoDeleteReplies) {
    return autoDeleteReplies ? "days" : "hours";
  },

  @discourseComputed("topic.visible")
  excludeCategoryId(visible) {
    if (visible) return this.get("topic.category_id");
  },

  @observes("selection")
  _updateBasedOnLastPost() {
    if (!this.autoClose) {
      schedule("afterRender", () => {
        this.set("topicTimer.based_on_last_post", false);
      });
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);

    // TODO: get rid of this hack
    schedule("afterRender", () => {
      if (!this.get("topicTimer.status_type")) {
        this.set(
          "topicTimer.status_type",
          this.get("timerTypes.firstObject.id")
        );
      }
    });
  }
});
