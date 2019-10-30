import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import {
  default as computed,
  observes,
  on
} from "ember-addons/ember-computed-decorators";

import {
  PUBLISH_TO_CATEGORY_STATUS_TYPE,
  OPEN_STATUS_TYPE,
  DELETE_STATUS_TYPE,
  REMINDER_TYPE,
  CLOSE_STATUS_TYPE,
  BUMP_TYPE
} from "discourse/controllers/edit-topic-timer";

export default Component.extend({
  selection: Ember.computed.alias("topicTimer.status_type"),
  autoOpen: Ember.computed.equal("selection", OPEN_STATUS_TYPE),
  autoClose: Ember.computed.equal("selection", CLOSE_STATUS_TYPE),
  autoDelete: Ember.computed.equal("selection", DELETE_STATUS_TYPE),
  autoBump: Ember.computed.equal("selection", BUMP_TYPE),
  publishToCategory: Ember.computed.equal(
    "selection",
    PUBLISH_TO_CATEGORY_STATUS_TYPE
  ),
  reminder: Ember.computed.equal("selection", REMINDER_TYPE),
  showTimeOnly: Ember.computed.or(
    "autoOpen",
    "autoDelete",
    "reminder",
    "autoBump"
  ),

  @computed(
    "topicTimer.updateTime",
    "loading",
    "publishToCategory",
    "topicTimer.category_id"
  )
  saveDisabled(updateTime, loading, publishToCategory, topicTimerCategoryId) {
    return (
      Ember.isEmpty(updateTime) ||
      loading ||
      (publishToCategory && !topicTimerCategoryId)
    );
  },

  @computed("topic.visible")
  excludeCategoryId(visible) {
    if (visible) return this.get("topic.category_id");
  },

  @on("init")
  @observes("topicTimer", "topicTimer.execute_at", "topicTimer.duration")
  _setUpdateTime() {
    let time = null;
    const executeAt = this.get("topicTimer.execute_at");

    if (executeAt && this.get("topicTimer.based_on_last_post")) {
      time = this.get("topicTimer.duration");
    } else if (executeAt) {
      const closeTime = moment(executeAt);

      if (closeTime > moment()) {
        time = closeTime.format("YYYY-MM-DD HH:mm");
      }
    }

    this.set("topicTimer.updateTime", time);
  },

  @observes("selection")
  _updateBasedOnLastPost() {
    if (!this.autoClose) {
      schedule("afterRender", () => {
        this.set("topicTimer.based_on_last_post", false);
      });
    }
  }
});
