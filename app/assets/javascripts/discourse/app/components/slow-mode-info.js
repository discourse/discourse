import { durationTextFromSeconds } from "discourse/helpers/slow-mode";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import Topic from "discourse/models/topic";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";

export default Component.extend({
  @discourseComputed("topic.slow_mode_seconds")
  durationText(seconds) {
    return durationTextFromSeconds(seconds);
  },

  @discourseComputed("topic.slow_mode_seconds", "topic.closed")
  showSlowModeNotice(seconds, closed) {
    return seconds > 0 && !closed;
  },

  @action
  disableSlowMode() {
    Topic.setSlowMode(this.topic.id, 0)
      .catch(popupAjaxError)
      .then(() => this.set("topic.slow_mode_seconds", 0));
  },
});
